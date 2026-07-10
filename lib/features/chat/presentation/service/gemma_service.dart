// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/chat/presentation/service/chat_runtime_gateway.dart';
import 'package:disastron/features/chat/presentation/service/xnnpack_cache_cleanup.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

const String kDisasterSystemInstruction = '''
You are Disastron, a concise offline assistant for emergencies: wars, natural disasters, transport accidents, fires, medical crises. Give practical, calm, step-by-step guidance. If information is uncertain, say so. Do not claim real-time data you cannot have offline. Prioritize safety, evacuation, shelter, first aid basics, and contacting local authorities when possible.

When you suggest checklist items the user should track, append EXACTLY one block at the END of your reply:
[[TODOS]]
{"ops":[{"op":"add","title":"Short actionable item"},{"op":"setDone","id":"<existing-id>","done":true}]}
[[/TODOS]]

Use only ops add / setDone / remove. For setDone/remove you must use todo ids from context when known; otherwise only use add. Keep titles short. If no checklist updates, omit the entire [[TODOS]] block.
''';

class GemmaLocalService {
  GemmaLocalService({ChatRuntimeGateway? runtime})
    : _runtime = runtime ?? const FlutterGemmaChatRuntimeGateway();

  /// The KV-cache budget shared by prompt, history, and reply.
  static const int _kContextWindowTokens = 2048;

  /// Caps the reply only. Emergency guidance should be short and actionable,
  /// and an unbounded reply can eat the whole [_kContextWindowTokens] budget.
  static const int _kMaxReplyTokens = 512;

  /// Disastron holds exactly one chat. Capping turns a second session — which
  /// would allocate a second KV cache and risk an OOM kill — into a StateError.
  static const int _kMaxConcurrentSessions = 1;

  InferenceModel? _model;
  InferenceChat? _chat;
  final ChatRuntimeGateway _runtime;
  bool? _lastInitSupportImage;

  /// Fresh dashboard snapshot text applied to the **next** user turn only
  /// (avoids recreating [InferenceChat] and desyncing UI vs native history).
  String? _pendingDeviceContextSituation;

  bool get isInitialized => _chat != null;

  void setDeviceContextForNextUserMessage(String situationText) {
    final String t = situationText.trim();
    _pendingDeviceContextSituation = t.isEmpty ? 'context_error: empty' : t;
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
    await _chat?.close();
    _chat = null;
    _chat = await _model!.createChat(
      systemInstruction: systemInstruction,
      supportImage: supportImage,
      loraPath: loraPath,
      maxOutputTokens: _kMaxReplyTokens,
      // Omitting this silently defaults to ModelType.gemmaIt, which routes a
      // gemma4 model through gemmaIt's thinking filter and function-call parser.
      modelType: _runtime.activeModelType(),
    );
  }

  // Deliberately no stopGeneration() wrapper. InferenceChat.stopGeneration()
  // reaches litert_lm_conversation_cancel_process, which leaves the native
  // conversation permanently wedged: the Dart stream closes cleanly, but every
  // later message on that conversation prefills forever and never emits a
  // token. Reproduced on Gemma 4 E2B with flutter_gemma_litertlm 1.0.2. The
  // stop button therefore only drops our subscription; the engine keeps
  // decoding unobserved until it reaches a stop token.

  Stream<ModelResponse> processMessageAsync(Message userMessage) async* {
    final InferenceChat chat = _chat!;
    Message toSend = userMessage;
    final String? pending = _pendingDeviceContextSituation;
    if (pending != null) {
      _pendingDeviceContextSituation = null;
      toSend = userMessage.copyWith(
        text:
            '[Device context refresh — offline estimates; use for this reply]\n'
            '$pending\n\n---\n\n${userMessage.text}',
        isUser: true,
      );
    }
    await chat.addQuery(toSend);
    yield* chat.generateChatResponseAsync();
  }

  Future<void> close() async {
    _pendingDeviceContextSituation = null;
    _lastInitSupportImage = null;
    await _chat?.close();
    _chat = null;
    await _model?.close();
    _model = null;
  }
}
