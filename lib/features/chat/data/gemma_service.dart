// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/chat/data/chat_runtime_gateway.dart';
import 'package:disastron/features/chat/data/xnnpack_cache_cleanup.dart';
import 'package:disastron/features/chat/domain/checklist_tool.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';

const String kDisasterSystemInstructionBase = '''
You are Disastron, a concise offline assistant for emergencies: wars, natural disasters, transport accidents, fires, medical crises. Give practical, calm, step-by-step guidance. If information is uncertain, say so. Do not claim real-time data you cannot have offline. Prioritize safety, evacuation, shelter, first aid basics, and contacting local authorities when possible.
''';

const String kLegacyTodosSystemInstructionAppend = '''

When you suggest checklist items the user should track, append EXACTLY one block at the END of your reply:
[[TODOS]]
{"ops":[{"op":"add","title":"Short actionable item"},{"op":"setDone","id":"<existing-id>","done":true}]}
[[/TODOS]]

Use only ops add / setDone / remove. For setDone/remove you must use todo ids from context when known; otherwise only use add. Keep titles short. If no checklist updates, omit the entire [[TODOS]] block.
''';

/// Full system prompt for models without native tool calling (e.g. Gemma 3 `.task`).
const String kDisasterSystemInstruction =
    '$kDisasterSystemInstructionBase$kLegacyTodosSystemInstructionAppend';

class GemmaLocalService {
  GemmaLocalService({ChatRuntimeGateway? runtime})
    : _runtime = runtime ?? const FlutterEdgeAiChatRuntimeGateway();

  /// The KV-cache budget shared by prompt, history, and reply.
  static const int _kContextWindowTokens = 2048;

  /// Caps the reply only. Emergency guidance should be short and actionable,
  /// and an unbounded reply can eat the whole [_kContextWindowTokens] budget.
  static const int _kMaxReplyTokens = 512;

  /// Disastron holds exactly one chat. Capping turns a second session — which
  /// would allocate a second KV cache and risk an OOM kill — into a StateError.
  static const int _kMaxConcurrentSessions = 1;

  static const int _kMaxChecklistToolTurns = 3;

  InferenceModel? _model;
  InferenceChat? _chat;
  final ChatRuntimeGateway _runtime;
  bool? _lastInitSupportImage;
  bool _usesNativeChecklistTools = false;

  /// Fresh dashboard snapshot text applied to the **next** user turn only
  /// (avoids recreating [InferenceChat] and desyncing UI vs native history).
  String? _pendingDeviceContextSituation;

  /// Open checklist snapshot for the next user turn (Gemma 4 tool path).
  String? _pendingChecklistSnapshot;

  ChecklistTurnResult? _lastChecklistTurnResult;

  /// Set when the user stops an in-flight generation. On the `.litertlm` FFI
  /// engine, cancelling the response stream reaches
  /// `litert_lm_conversation_cancel_process`, which leaves the native
  /// conversation wedged: every later turn prefills forever and emits no token
  /// (reproduced on Gemma 4 E2B, flutter_gemma_litertlm 1.1.0). The recovery
  /// flutter_gemma documents is close+recreate with history replay; we defer it
  /// to the next turn (see [processMessageAsync]) so the stop itself stays
  /// instant and we only pay the re-prefill cost if the user actually continues.
  bool _needsSessionReset = false;

  bool get isInitialized => _chat != null;

  /// True after [init] when the active model is Gemma 4 on `.litertlm`.
  bool get usesNativeChecklistTools => _usesNativeChecklistTools;

  void setDeviceContextForNextUserMessage(String situationText) {
    final String t = situationText.trim();
    _pendingDeviceContextSituation = t.isEmpty ? 'context_error: empty' : t;
  }

  void setChecklistSnapshotForNextUserMessage(String snapshotText) {
    final String t = snapshotText.trim();
    _pendingChecklistSnapshot = t.isEmpty ? null : t;
  }

  /// Native tool path only: checklist ops applied on the last completed turn.
  ChecklistTurnResult? takeLastChecklistTurnResult() {
    final ChecklistTurnResult? r = _lastChecklistTurnResult;
    _lastChecklistTurnResult = null;
    return r;
  }

  /// Creates or refreshes the chat session. Loads the active inference model
  /// when none is loaded; set [reloadInferenceWeights] on first load only.
  /// [supportImage] must match the active model capabilities (see registry).
  Future<void> init({
    String? systemInstruction,
    bool reloadInferenceWeights = false,
    bool supportImage = false,
    int? maxNumImages,
    String? loraPath,
    bool useNativeChecklistTools = false,
  }) async {
    final bool visionFlagChanged =
        _lastInitSupportImage != null && _lastInitSupportImage != supportImage;
    if (_model != null && visionFlagChanged) {
      await _chat?.close();
      _chat = null;
      await _model!.close();
      _model = null;
    }
    _lastInitSupportImage = supportImage;

    if (_model == null) {
      if (reloadInferenceWeights) {
        await clearTfliteXnnpackWeightCaches();
      }
      _model = await _runtime.getActiveModel(
        maxTokens: _kContextWindowTokens,
        supportImage: supportImage,
        maxNumImages: maxNumImages,
        maxConcurrentSessions: _kMaxConcurrentSessions,
      );
    }

    final ModelType? activeType = _runtime.activeModelType();
    _usesNativeChecklistTools =
        useNativeChecklistTools &&
        modelSupportsNativeChecklistTools(
          modelType: activeType,
          fileType: _model!.fileType,
        );

    await _chat?.close();
    _chat = null;
    _chat = await _model!.createChat(
      systemInstruction: systemInstruction,
      supportImage: supportImage,
      loraPath: loraPath,
      maxOutputTokens: _kMaxReplyTokens,
      tools: _usesNativeChecklistTools
          ? <Tool>[kUpdateChecklistTool]
          : const <Tool>[],
      supportsFunctionCalls: _usesNativeChecklistTools,
      // Omitting this silently defaults to ModelType.gemmaIt, which routes a
      // gemma4 model through gemmaIt's thinking filter and function-call parser.
      modelType: activeType,
    );
    // Fresh chat — no wedged session to recover from.
    _needsSessionReset = false;
  }

  /// Records that an in-flight generation was stopped (stop button or the
  /// message widget being torn down mid-stream). The wedged native session is
  /// rebuilt lazily on the next [processMessageAsync]; see [_needsSessionReset].
  void markGenerationStopped() {
    _needsSessionReset = true;
  }

  Stream<ModelResponse> processMessageAsync(
    Message userMessage, {
    Future<Map<String, dynamic>> Function(
      FunctionCallResponse call,
      List<Map<String, dynamic>> ops,
    )?
    onChecklistToolCall,
  }) async* {
    _lastChecklistTurnResult = null;
    final InferenceChat chat = _chat!;
    if (_needsSessionReset) {
      _needsSessionReset = false;
      await chat.clearHistory(replayHistory: chat.fullHistory);
    }
    Message toSend = userMessage;
    final String? pendingSituation = _pendingDeviceContextSituation;
    if (pendingSituation != null) {
      _pendingDeviceContextSituation = null;
      toSend = _prependUserContext(
        toSend,
        '[Device context refresh — offline estimates; use for this reply]\n'
        '$pendingSituation',
      );
    }
    final String? pendingChecklist = _pendingChecklistSnapshot;
    if (pendingChecklist != null) {
      _pendingChecklistSnapshot = null;
      toSend = _prependUserContext(toSend, pendingChecklist);
    }
    await chat.addQuery(toSend);

    if (_usesNativeChecklistTools && onChecklistToolCall != null) {
      yield* chat.generateChatResponseWithTools(
        maxToolTurns: _kMaxChecklistToolTurns,
        onToolCall: (FunctionCallResponse call) async {
          if (call.name != kUpdateChecklistToolName) {
            return <String, dynamic>{'error': 'unknown tool ${call.name}'};
          }
          final List<Map<String, dynamic>> ops = checklistOpsFromToolArgs(
            call.args,
          );
          final Map<String, dynamic> response = await onChecklistToolCall(
            call,
            ops,
          );
          final int applied = response['applied'] as int? ?? ops.length;
          final int added = response['added'] as int? ?? 0;
          _lastChecklistTurnResult = ChecklistTurnResult(
            appliedCount: applied,
            addedTodoCount: added,
          );
          return response;
        },
      );
      return;
    }

    yield* chat.generateChatResponseAsync();
  }

  Message _prependUserContext(Message userMessage, String prefix) {
    return userMessage.copyWith(
      text: '$prefix\n\n---\n\n${userMessage.text}',
      isUser: true,
    );
  }

  Future<void> close() async {
    _pendingDeviceContextSituation = null;
    _pendingChecklistSnapshot = null;
    _lastChecklistTurnResult = null;
    _usesNativeChecklistTools = false;
    _needsSessionReset = false;
    _lastInitSupportImage = null;
    await _chat?.close();
    _chat = null;
    await _model?.close();
    _model = null;
  }
}
