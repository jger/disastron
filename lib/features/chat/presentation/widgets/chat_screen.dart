import 'dart:async';
import 'dart:typed_data';

import 'package:disastron/features/chat/presentation/chat_dashboard_situation_provider.dart';
import 'package:disastron/features/chat/presentation/chat_handlers.dart';
import 'package:disastron/features/chat/presentation/chat_reset_provider.dart';
import 'package:disastron/features/chat/presentation/first_chat_accident_provider.dart';
import 'package:disastron/features/chat/presentation/service/chat_dashboard_context.dart';
import 'package:disastron/features/chat/presentation/service/chat_init_debug_log.dart';
import 'package:disastron/features/chat/presentation/service/gemma_service.dart';
import 'package:disastron/features/chat/presentation/service/todo_action_parser.dart';
import 'package:disastron/features/chat/presentation/widgets/accident_chips_panel.dart';
import 'package:disastron/features/chat/presentation/widgets/chat_widget.dart';
import 'package:disastron/features/chat/presentation/widgets/loading_widget.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_device_provider.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_weather_provider.dart';
import 'package:disastron/features/home_shell/presentation/home_tab_index_provider.dart';
import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:disastron/features/inference/presentation/inference_model_vision_support.dart';
import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:disastron/features/inference/presentation/lora_provider.dart';
import 'package:disastron/features/inference/presentation/model_registry_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final GemmaLocalService _gemma = GemmaLocalService();
  final List<Message> _messages = <Message>[];
  bool _chatReady = false;
  String? _initError;
  bool _showWarningBanner = true;

  /// Effective image attach support after init (native engine may refuse vision).
  bool _runtimeImageSupportEnabled = false;

  /// Cached container reference so we can safely clear chatResetProvider
  /// inside [dispose], where [ref] is no longer safe to use.
  late ProviderContainer _container;
  int _ensureChatReadySeq = 0;

  @override
  void initState() {
    super.initState();
    // Cache before any async work so dispose() can use it safely.
    _container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
      unawaited(_ensureChatReady(reloadInferenceWeights: true));
    });
  }

  @override
  void dispose() {
    // Use cached container — ref is unsafe to call after unmount.
    _container.read(chatResetProvider.notifier).state = null;
    unawaited(_gemma.close());
    super.dispose();
  }

  /// Returns the device/weather situation block, or null on any error.
  /// Null means "skip context injection" so errors are never leaked into chat.
  Future<String?> _loadFreshSituationString() async {
    ref
      ..invalidate(dashboardLocationProvider)
      ..invalidate(dashboardBatteryProvider)
      ..invalidate(dashboardWeatherProvider);
    try {
      return await ref.read(chatDashboardSituationProvider.future);
    } on Object {
      return null;
    }
  }

  /// When user switches back to Chat, refresh dashboard samples and attach
  /// them to the **next** user message (recreating [InferenceChat] would drop
  /// native multi-turn history while the UI still shows old bubbles).
  Future<void> _scheduleDeviceContextInjectIfEnteredChatTab({
    required int? previousIndex,
    required int nextIndex,
  }) async {
    if (nextIndex != kHomeTabIndexChat) {
      return;
    }
    if (previousIndex == kHomeTabIndexChat) {
      return;
    }
    if (!FlutterGemma.hasActiveModel() || !_chatReady) {
      return;
    }
    final bool useCtx = ref.read(useDisastronContextProvider);
    if (!useCtx) {
      return;
    }
    final String? situation = await _loadFreshSituationString();
    if (!mounted || situation == null) {
      return;
    }
    _gemma.setDeviceContextForNextUserMessage(situation);
  }

  void _markChatReady({
    required bool runtimeVisionEnabled,
    required bool showVisionFallbackSnack,
    required int seq,
  }) {
    if (!mounted || seq != _ensureChatReadySeq) {
      chatInitLog(
        '_markChatReady#$seq ignored',
        'mounted=$mounted superseded=${seq != _ensureChatReadySeq}',
      );
      return;
    }
    setState(() {
      _chatReady = true;
      _initError = null;
      _runtimeImageSupportEnabled = runtimeVisionEnabled;
    });
    ref.read(chatResetProvider.notifier).state =
        () => unawaited(_confirmResetChat(context));
    if (showVisionFallbackSnack) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('chat_vision_fallback_snack'.tr()),
          ),
        );
      });
    }
  }

  Future<void> _ensureChatReady({required bool reloadInferenceWeights}) async {
    final int seq = ++_ensureChatReadySeq;
    chatInitLog(
      '_ensureChatReady#$seq start',
      'reloadWeights=$reloadInferenceWeights '
          'hasActiveModel=${FlutterGemma.hasActiveModel()} chatReady=$_chatReady',
    );
    try {
      if (!FlutterGemma.hasActiveModel()) {
        chatInitLog('_ensureChatReady#$seq early return — no active model');
        return;
      }
      final bool useCtx = ref.read(useDisastronContextProvider);
      final String? system;
      if (useCtx) {
        chatInitLog('_ensureChatReady#$seq loading device context…');
        final String? situation = await _loadFreshSituationString();
        chatInitLog(
          '_ensureChatReady#$seq device context done',
          situation == null ? 'null' : '${situation.length} chars',
        );
        system = situation != null
            ? composeDisasterSystemInstruction(situation)
            : kDisasterSystemInstruction.trim();
      } else {
        system = null;
      }
      chatInitLog('_ensureChatReady#$seq loading registry…');
      final ModelRegistrySnapshot registry =
          await ref.read(modelRegistrySnapshotProvider.future);
      final bool visionRequested = activeRegistryEntrySupportsVision(registry);
      chatInitLog(
        '_ensureChatReady#$seq registry done',
        'active=${registry.activeEntryId} vision=$visionRequested',
      );

      final String? activeEntryId = registry.activeEntryId;
      String? loraPath;
      if (activeEntryId != null) {
        chatInitLog('_ensureChatReady#$seq loading lora path…');
        loraPath = await ref.read(activeLoraPathProvider(activeEntryId).future);
        chatInitLog('_ensureChatReady#$seq lora path', loraPath ?? 'none');
      }

      if (visionRequested) {
        try {
          chatInitLog('_ensureChatReady#$seq gemma.init vision…');
          await _gemma.init(
            systemInstruction: system,
            reloadInferenceWeights: reloadInferenceWeights,
            supportImage: true,
            maxNumImages: 1,
            loraPath: loraPath,
          );
          chatInitLog('_ensureChatReady#$seq gemma.init vision done');
          _markChatReady(
            runtimeVisionEnabled: true,
            showVisionFallbackSnack: false,
            seq: seq,
          );
          chatInitLog('_ensureChatReady#$seq complete (vision)');
          return;
        } on Object catch (e, st) {
          chatInitLog('_ensureChatReady#$seq vision init failed', e);
          chatInitLog('_ensureChatReady#$seq vision stack', st);
          await _gemma.close();
          if (!mounted) {
            chatInitLog(
              '_ensureChatReady#$seq aborted — unmounted after vision fail',
            );
            return;
          }
          chatInitLog('_ensureChatReady#$seq gemma.init text fallback…');
          await _gemma.init(
            systemInstruction: system,
            loraPath: loraPath,
          );
          _markChatReady(
            runtimeVisionEnabled: false,
            showVisionFallbackSnack: true,
            seq: seq,
          );
          chatInitLog('_ensureChatReady#$seq complete (text fallback)');
          return;
        }
      }

      chatInitLog('_ensureChatReady#$seq gemma.init text…');
      await _gemma.init(
        systemInstruction: system,
        reloadInferenceWeights: reloadInferenceWeights,
        loraPath: loraPath,
      );
      chatInitLog('_ensureChatReady#$seq gemma.init text done');
      _markChatReady(
        runtimeVisionEnabled: false,
        showVisionFallbackSnack: false,
        seq: seq,
      );
      chatInitLog('_ensureChatReady#$seq complete (text)');
    } on Object catch (e, st) {
      chatInitLog('_ensureChatReady#$seq failed', e);
      chatInitLog('_ensureChatReady#$seq stack', st);
      if (mounted && seq == _ensureChatReadySeq) {
        setState(() {
          _chatReady = false;
          _runtimeImageSupportEnabled = false;
          _initError = e.toString();
        });
        ref.read(chatResetProvider.notifier).state = null;
      }
    } finally {
      chatInitLog('_ensureChatReady#$seq end');
    }
  }

  Future<void> _onAssistantMessage(Message message) async {
    final TodoApplyResult result = await stripTodosAndApply(ref, message.text);
    if (!mounted) {
      return;
    }
    final String trimmedDisplay = result.displayText.trim();
    final String assistantBody = trimmedDisplay.isEmpty
        ? (result.appliedCount > 0
            ? 'chat_checklist_updated'.tr()
            : 'chat_no_response'.tr())
        : trimmedDisplay;
    setState(() {
      _messages.add(Message.text(text: assistantBody));
      if (result.appliedCount > 0) {
        final String hint = result.addedTodoCount > 0
            ? 'chat_checklist_new_badge'.tr(
                namedArgs: <String, String>{
                  'count': '${result.addedTodoCount}',
                },
              )
            : 'chat_checklist_review'.tr();
        _messages.add(
          Message(
            text: 'chat_checklist_summary'.tr(
              namedArgs: <String, String>{
                'count': '${result.appliedCount}',
                'hint': hint,
              },
            ),
            type: MessageType.systemInfo,
          ),
        );
      }
    });
  }

  void _onHumanMessage(ChatMessageDraft draft) {
    if (!draft.isNotEmpty) {
      return;
    }
    unawaited(ref.read(firstChatAccidentPromptProvider.notifier).markDone());
    final String trimmed = draft.text.trim();
    final Uint8List? img = draft.imageBytes;
    final Message userMsg;
    if (img != null && img.isNotEmpty) {
      userMsg = trimmed.isEmpty
          ? Message.imageOnly(imageBytes: img, isUser: true)
          : Message.withImage(text: trimmed, imageBytes: img, isUser: true);
    } else {
      userMsg = Message.text(text: trimmed, isUser: true);
    }
    setState(() {
      _messages.add(userMsg);
    });
  }

  void _onAccidentChip(AccidentChipOption option) {
    unawaited(ref.read(firstChatAccidentPromptProvider.notifier).markDone());
    setState(() {
      _messages.add(Message.text(text: option.prompt, isUser: true));
    });
  }

  Future<void> _confirmResetChat(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('chat_reset_title'.tr()),
        content: Text('chat_reset_body'.tr()),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('chat_reset_confirm'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    await _performReset(reloadInferenceWeights: true);
  }

  Future<void> _performReset({required bool reloadInferenceWeights}) async {
    await _gemma.close();
    if (!mounted) {
      return;
    }
    await ref.read(firstChatAccidentPromptProvider.notifier).reset();
    if (!mounted) {
      return;
    }
    setState(() {
      _messages.clear();
      _chatReady = false;
      _runtimeImageSupportEnabled = false;
      _initError = null;
      _showWarningBanner = true;
    });
    ref.read(chatResetProvider.notifier).state = null;
    await _ensureChatReady(reloadInferenceWeights: reloadInferenceWeights);
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen<int>(homeBottomNavIndexProvider, (int? previous, int next) {
        if (next == kHomeTabIndexChat && previous != kHomeTabIndexChat) {
          setState(() {
            _showWarningBanner = true;
          });
        }
        unawaited(
          _scheduleDeviceContextInjectIfEnteredChatTab(
            previousIndex: previous,
            nextIndex: next,
          ),
        );
      })
      ..listen<LocalGemmaModelUi>(
        localGemmaModelProvider,
        (LocalGemmaModelUi? previous, LocalGemmaModelUi next) {
          chatInitLog(
            'localGemmaModelProvider changed',
            'prev=${previous?.phase} next=${next.phase} chatReady=$_chatReady',
          );
          if (next.isReady && !_chatReady) {
            unawaited(_ensureChatReady(reloadInferenceWeights: true));
          }
          if (!next.isReady && _chatReady) {
            chatInitLog('model not ready — closing gemma session');
            unawaited(_gemma.close());
            if (mounted) {
              setState(() {
                _chatReady = false;
                _runtimeImageSupportEnabled = false;
                _messages.clear();
                _initError = null;
              });
              ref.read(chatResetProvider.notifier).state = null;
            }
          }
        },
      )
      ..listen<bool>(
        useDisastronContextProvider,
        (bool? previous, bool next) {
          if (previous != null && previous != next) {
            unawaited(_performReset(reloadInferenceWeights: false));
          }
        },
      );

    final LocalGemmaModelUi modelUi = ref.watch(localGemmaModelProvider);
    final AsyncValue<bool> accidentDone =
        ref.watch(firstChatAccidentPromptProvider);
    final bool showAccidentChips = modelUi.isReady &&
        _chatReady &&
        accidentDone.hasValue &&
        accidentDone.requireValue == false &&
        _messages.isEmpty;

    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: <Widget>[
          if (!modelUi.isReady)
            _NoModelBody(
              onRefresh: () {
                ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
                unawaited(_ensureChatReady(reloadInferenceWeights: true));
              },
            )
          else if (_initError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  'chat_init_failed'.tr(
                    namedArgs: <String, String>{'error': _initError!},
                  ),
                ),
              ),
            )
          else if (!_chatReady)
            LoadingWidget(
              message: 'chat_starting'.tr(),
            )
          else
            Column(
              children: <Widget>[
                if (_showWarningBanner)
                  _ChatWarningBanner(
                    onDismiss: () {
                      setState(() {
                        _showWarningBanner = false;
                      });
                    },
                  ),
                Expanded(
                  child: ChatListWidget(
                    gemmaService: _gemma,
                    showAccidentChips: showAccidentChips,
                    onAccidentChip: _onAccidentChip,
                    gemmaHandler: _onAssistantMessage,
                    humanHandler: _onHumanMessage,
                    messages: _messages,
                    isImageSupported: _runtimeImageSupportEnabled,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NoModelBody extends StatelessWidget {
  const _NoModelBody({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'chat_no_model_body'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRefresh,
              child: Text('chat_check_again'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatWarningBanner extends StatelessWidget {
  const _ChatWarningBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.warning_amber_rounded,
            color: cs.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'chat_llm_warning'.tr(),
              style: TextStyle(
                color: cs.onErrorContainer,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: cs.onErrorContainer,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
