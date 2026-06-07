import 'dart:async';
import 'dart:typed_data';

import 'package:disastron/features/chat/presentation/chat_dashboard_situation_provider.dart';
import 'package:disastron/features/chat/presentation/chat_handlers.dart';
import 'package:disastron/features/chat/presentation/chat_reset_provider.dart';
import 'package:disastron/features/chat/presentation/first_chat_accident_provider.dart';
import 'package:disastron/features/chat/presentation/service/chat_dashboard_context.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
      unawaited(_ensureChatReady(reloadInferenceWeights: true));
    });
  }

  @override
  void dispose() {
    ref.read(chatResetProvider.notifier).state = null;
    unawaited(_gemma.close());
    super.dispose();
  }

  Future<String> _loadFreshSituationString() async {
    ref
      ..invalidate(dashboardDeviceProvider)
      ..invalidate(dashboardWeatherProvider);
    try {
      return await ref.read(chatDashboardSituationProvider.future);
    } on Object catch (e) {
      return formatChatDashboardSituationError(e);
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
    final String situation = await _loadFreshSituationString();
    if (!mounted) {
      return;
    }
    _gemma.setDeviceContextForNextUserMessage(situation);
  }

  void _markChatReady({
    required bool runtimeVisionEnabled,
    required bool showVisionFallbackSnack,
  }) {
    if (!mounted) {
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
          const SnackBar(
            content: Text(
              'Image input disabled: vision engine could not start on this '
              'device. Text chat still works.',
            ),
          ),
        );
      });
    }
  }

  Future<void> _ensureChatReady({required bool reloadInferenceWeights}) async {
    if (!FlutterGemma.hasActiveModel()) {
      return;
    }
    try {
      final String situation = await _loadFreshSituationString();
      final String system = composeDisasterSystemInstruction(situation);
      final ModelRegistrySnapshot registry =
          await ref.read(modelRegistrySnapshotProvider.future);
      final bool visionRequested = activeRegistryEntrySupportsVision(registry);

      final String? activeEntryId = registry.activeEntryId;
      String? loraPath;
      if (activeEntryId != null) {
        loraPath = await ref.read(activeLoraPathProvider(activeEntryId).future);
      }

      if (visionRequested) {
        try {
          await _gemma.init(
            systemInstruction: system,
            reloadInferenceWeights: reloadInferenceWeights,
            supportImage: true,
            maxNumImages: 1,
            loraPath: loraPath,
          );
          _markChatReady(
            runtimeVisionEnabled: true,
            showVisionFallbackSnack: false,
          );
          return;
        } on Object catch (_) {
          await _gemma.close();
          if (!mounted) {
            return;
          }
          await _gemma.init(
            systemInstruction: system,
            loraPath: loraPath,
          );
          _markChatReady(
            runtimeVisionEnabled: false,
            showVisionFallbackSnack: true,
          );
          return;
        }
      }

      await _gemma.init(
        systemInstruction: system,
        reloadInferenceWeights: reloadInferenceWeights,
        loraPath: loraPath,
      );
      _markChatReady(
        runtimeVisionEnabled: false,
        showVisionFallbackSnack: false,
      );
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _chatReady = false;
          _runtimeImageSupportEnabled = false;
          _initError = e.toString();
        });
        ref.read(chatResetProvider.notifier).state = null;
      }
    }
  }

  Future<void> _onAssistantMessage(Message message) async {
    final TodoApplyResult result = await stripTodosAndApply(ref, message.text);
    if (!mounted) {
      return;
    }
    final String trimmedDisplay = result.displayText.trim();
    final String assistantBody =
        trimmedDisplay.isEmpty ? '(Checklist updated.)' : trimmedDisplay;
    setState(() {
      _messages.add(Message.text(text: assistantBody));
      if (result.appliedCount > 0) {
        final String hint = result.addedTodoCount > 0
            ? ' ${result.addedTodoCount} new on Todos (tab badge).'
            : ' Open the Todos tab to review.';
        _messages.add(
          Message(
            text: 'Checklist updated (${result.appliedCount} action(s)).$hint',
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
        title: const Text('Reset chat?'),
        content: const Text(
          'All messages in this session will be cleared and the first-run '
          'quick actions will appear again.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
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
    await _ensureChatReady(reloadInferenceWeights: true);
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
          if (next.isReady && !_chatReady) {
            unawaited(_ensureChatReady(reloadInferenceWeights: true));
          }
          if (!next.isReady && _chatReady) {
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
                child: SelectableText('Chat init failed: $_initError'),
              ),
            )
          else if (!_chatReady)
            const LoadingWidget(
              message: 'Starting offline assistant…',
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
              'No on-device model yet. Open the Dashboard tab, then import a model file '
              'or download one when you have a network connection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRefresh,
              child: const Text('Check again'),
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
