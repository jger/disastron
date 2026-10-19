import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:disastron/features/chat/chat.dart';
import 'package:disastron/features/chat/data/gemma_service.dart';
import 'package:disastron/features/chat/domain/chat_dashboard_context.dart';
import 'package:disastron/features/chat/domain/checklist_tool.dart';
import 'package:disastron/features/chat/domain/todo_action_parser.dart';
import 'package:disastron/features/chat/presentation/chat_dashboard_situation_provider.dart';
import 'package:disastron/features/chat/presentation/chat_handlers.dart';
import 'package:disastron/features/chat/presentation/widgets/accident_chips_panel.dart';
import 'package:disastron/features/chat/presentation/widgets/chat_widget.dart';
import 'package:disastron/features/chat/presentation/widgets/loading_widget.dart';
import 'package:disastron/features/dashboard/dashboard.dart';
import 'package:disastron/features/home/home.dart';
import 'package:disastron/features/inference/inference.dart';
import 'package:disastron/features/todos/todos.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
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
  bool _initInFlight = false;

  /// Effective image attach support after init (native engine may refuse vision).
  bool _runtimeImageSupportEnabled = false;

  /// Cached container reference so we can safely clear chatResetProvider
  /// inside [dispose], where [ref] is no longer safe to use.
  late ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    // Cache before any async work so dispose() can use it safely.
    _container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
      unawaited(_ensureChatReady(reloadInferenceWeights: false));
    });
  }

  @override
  void dispose() {
    // Use cached container — ref is unsafe to call after unmount.
    _container.read(chatResetProvider.notifier).state = null;
    unawaited(_gemma.close());
    super.dispose();
  }

  /// Refreshes dashboard samples (slow: GPS/geocoding). Use for injecting context
  /// into the next user turn, not for blocking chat session creation.
  Future<String> _loadFreshSituationString() async {
    ref
      ..invalidate(dashboardLocationProvider)
      ..invalidate(dashboardBatteryProvider)
      ..invalidate(dashboardWeatherProvider);
    try {
      return await ref.read(chatDashboardSituationProvider.future);
    } on Object catch (e) {
      return formatChatDashboardSituationError(e);
    }
  }

  /// Cached dashboard snapshot for [GemmaLocalService.init] — must not block
  /// the chat tab on a full location refresh.
  Future<String?> _situationForChatInit() async {
    try {
      return await ref
          .read(chatDashboardSituationProvider.future)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () =>
                'context_error: dashboard snapshot timed out after 5s',
          );
    } on Object catch (e) {
      return formatChatDashboardSituationError(e);
    }
  }

  void _logChatInit(String phase, Stopwatch sw) {
    developer.log(
      '$phase (+${sw.elapsedMilliseconds}ms)',
      name: 'disastron.chat_init',
    );
    debugPrint('[chat_init] $phase (+${sw.elapsedMilliseconds}ms)');
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
    if (!FlutterEdgeAi.hasActiveModel() || !_chatReady) {
      return;
    }
    final bool useCtx = ref.read(useDisastronContextProvider);
    if (!useCtx) {
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
    ref.read(chatResetProvider.notifier).state = () =>
        unawaited(_confirmResetChat(context));
    if (showVisionFallbackSnack) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('chat_vision_disabled_snack'.tr())),
        );
      });
    }
  }

  bool _nativeChecklistForRegistry(ModelRegistrySnapshot registry) {
    final String? activeId = registry.activeEntryId;
    if (activeId == null) {
      return false;
    }
    for (final InstalledModelEntry entry in registry.entries) {
      if (entry.id == activeId) {
        return modelSupportsNativeChecklistTools(
          modelType: entry.modelType,
          fileType: entry.fileType,
        );
      }
    }
    return false;
  }

  Future<void> _injectChecklistSnapshotForNextTurn() async {
    if (!_gemma.usesNativeChecklistTools) {
      return;
    }
    final List<EmergencyTodo> todos = await ref.read(
      emergencyTodosProvider.future,
    );
    _gemma.setChecklistSnapshotForNextUserMessage(
      formatChecklistSnapshotForUserTurn(todos),
    );
  }

  Future<Map<String, dynamic>> _onChecklistToolCall(
    FunctionCallResponse call,
    List<Map<String, dynamic>> ops,
  ) async {
    int addedTodoCount = 0;
    for (final Map<String, dynamic> op in ops) {
      if ((op['op'] as String?) == 'add' &&
          ((op['title'] as String?)?.trim().isNotEmpty ?? false)) {
        addedTodoCount++;
      }
    }
    if (ops.isNotEmpty) {
      await ref.read(emergencyTodosProvider.notifier).applyOps(ops);
      if (addedTodoCount > 0) {
        ref
            .read(todoTabBadgeProvider.notifier)
            .addFromAssistant(addedTodoCount);
      }
    }
    return <String, dynamic>{
      'status': 'ok',
      'applied': ops.length,
      'added': addedTodoCount,
    };
  }

  Future<void> _ensureChatReady({required bool reloadInferenceWeights}) async {
    if (!FlutterEdgeAi.hasActiveModel() || _initInFlight || _chatReady) {
      return;
    }
    _initInFlight = true;
    final Stopwatch sw = Stopwatch()..start();
    _logChatInit('start', sw);
    try {
      final ModelRegistryStore store = ModelRegistryStore();
      await store.migrateFromLegacyIfNeeded();
      final ModelRegistrySnapshot registry = await store.readSnapshot();
      _logChatInit('registry', sw);
      final bool nativeChecklist = _nativeChecklistForRegistry(registry);
      final bool useCtx = ref.read(useDisastronContextProvider);
      final String? situation = useCtx ? await _situationForChatInit() : null;
      _logChatInit('situation', sw);
      final String system = disasterChatSystemInstruction(
        nativeChecklist: nativeChecklist,
        situationBlock: situation,
      );
      final bool visionRequested = activeRegistryEntrySupportsVision(registry);

      final String? activeEntryId = registry.activeEntryId;
      String? loraPath;
      if (activeEntryId != null) {
        loraPath = await resolveActiveLoraPath(activeEntryId);
      }
      _logChatInit('lora ($loraPath)', sw);

      Future<void> initTextOnly() => _gemma
          .init(
            systemInstruction: system,
            reloadInferenceWeights: reloadInferenceWeights,
            loraPath: loraPath,
            useNativeChecklistTools: nativeChecklist,
          )
          .timeout(const Duration(minutes: 2));

      if (visionRequested) {
        try {
          await _gemma
              .init(
                systemInstruction: system,
                reloadInferenceWeights: reloadInferenceWeights,
                supportImage: true,
                maxNumImages: 1,
                loraPath: loraPath,
                useNativeChecklistTools: nativeChecklist,
              )
              .timeout(const Duration(minutes: 2));
          _logChatInit('gemma init (vision)', sw);
          _markChatReady(
            runtimeVisionEnabled: true,
            showVisionFallbackSnack: false,
          );
          return;
        } on Object catch (e) {
          _logChatInit('vision init failed ($e), text-only fallback', sw);
          await _gemma.close();
          if (!mounted) {
            return;
          }
          await initTextOnly();
          _logChatInit('gemma init (text fallback)', sw);
          _markChatReady(
            runtimeVisionEnabled: false,
            showVisionFallbackSnack: true,
          );
          return;
        }
      }

      await initTextOnly();
      _logChatInit('gemma init (text)', sw);
      _markChatReady(
        runtimeVisionEnabled: false,
        showVisionFallbackSnack: false,
      );
    } on Object catch (e) {
      _logChatInit('failed: $e', sw);
      if (mounted) {
        setState(() {
          _chatReady = false;
          _runtimeImageSupportEnabled = false;
          _initError = e.toString();
        });
        ref.read(chatResetProvider.notifier).state = null;
      }
    } finally {
      _initInFlight = false;
    }
  }

  Future<void> _onAssistantMessage(Message message) async {
    int appliedCount = 0;
    int addedTodoCount = 0;
    String displayText = message.text;
    if (_gemma.usesNativeChecklistTools) {
      final ChecklistTurnResult? toolResult = _gemma
          .takeLastChecklistTurnResult();
      if (toolResult != null && toolResult.appliedCount > 0) {
        appliedCount = toolResult.appliedCount;
        addedTodoCount = toolResult.addedTodoCount;
      } else {
        final TodoApplyResult legacy = await stripTodosAndApply(
          ref,
          message.text,
        );
        displayText = legacy.displayText;
        appliedCount = legacy.appliedCount;
        addedTodoCount = legacy.addedTodoCount;
      }
    } else {
      final TodoApplyResult result = await stripTodosAndApply(
        ref,
        message.text,
      );
      displayText = result.displayText;
      appliedCount = result.appliedCount;
      addedTodoCount = result.addedTodoCount;
    }
    if (!mounted) {
      return;
    }
    final String trimmedDisplay = displayText.trim();
    final String assistantBody = trimmedDisplay.isEmpty
        ? (appliedCount > 0
              ? 'chat_checklist_updated_short'.tr()
              : 'chat_no_response'.tr())
        : trimmedDisplay;
    setState(() {
      _messages.add(Message.text(text: assistantBody));
      if (appliedCount > 0) {
        final String hint = addedTodoCount > 0
            ? 'chat_checklist_hint_badge'.tr()
            : 'chat_checklist_hint_review'.tr();
        _messages.add(
          Message(
            text: 'chat_checklist_updated'.tr(
              args: <String>['$appliedCount', hint],
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
    unawaited(_submitHumanMessage(draft));
  }

  Future<void> _submitHumanMessage(ChatMessageDraft draft) async {
    await _injectChecklistSnapshotForNextTurn();
    await ref.read(firstChatAccidentPromptProvider.notifier).markDone();
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
    if (!mounted) {
      return;
    }
    setState(() {
      _messages.add(userMsg);
    });
  }

  void _onAccidentChip(AccidentChipOption option) {
    unawaited(_submitAccidentChip(option));
  }

  Future<void> _submitAccidentChip(AccidentChipOption option) async {
    await _injectChecklistSnapshotForNextTurn();
    await ref.read(firstChatAccidentPromptProvider.notifier).markDone();
    if (!mounted) {
      return;
    }
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
            child: Text('reset'.tr()),
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
          ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
          if (!_chatReady && !_initInFlight) {
            unawaited(_ensureChatReady(reloadInferenceWeights: false));
          }
        }
        unawaited(
          _scheduleDeviceContextInjectIfEnteredChatTab(
            previousIndex: previous,
            nextIndex: next,
          ),
        );
      })
      ..listen<LocalGemmaModelUi>(localGemmaModelProvider, (
        LocalGemmaModelUi? previous,
        LocalGemmaModelUi next,
      ) {
        if (next.isReady && !_chatReady && !_initInFlight) {
          unawaited(_ensureChatReady(reloadInferenceWeights: false));
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
      })
      ..listen<bool>(useDisastronContextProvider, (bool? previous, bool next) {
        if (previous != null && previous != next) {
          unawaited(_performReset(reloadInferenceWeights: false));
        }
      });

    final LocalGemmaModelUi modelUi = ref.watch(localGemmaModelProvider);

    if (modelUi.isReady &&
        !_chatReady &&
        !_initInFlight &&
        _initError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_chatReady && !_initInFlight && _initError == null) {
          unawaited(_ensureChatReady(reloadInferenceWeights: false));
        }
      });
    }
    final AsyncValue<bool> accidentDone = ref.watch(
      firstChatAccidentPromptProvider,
    );
    final bool showAccidentChips =
        modelUi.isReady &&
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
                unawaited(_ensureChatReady(reloadInferenceWeights: false));
              },
            )
          else if (_initError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  'chat_init_failed'.tr(args: <String>['$_initError']),
                ),
              ),
            )
          else if (!_chatReady)
            LoadingWidget(message: 'chat_starting_assistant'.tr())
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
                    onChecklistToolCall: _gemma.usesNativeChecklistTools
                        ? _onChecklistToolCall
                        : null,
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
