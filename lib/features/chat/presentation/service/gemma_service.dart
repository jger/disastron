import 'package:disastron/features/chat/presentation/service/chat_init_debug_log.dart';
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
    chatInitLog(
      'GemmaLocalService.init start',
      'reloadWeights=$reloadInferenceWeights supportImage=$supportImage '
          'hasModel=${_model != null} hasChat=${_chat != null}',
    );
    final bool visionFlagChanged =
        _lastInitSupportImage != null && _lastInitSupportImage != supportImage;
    if (_model != null && visionFlagChanged) {
      chatInitLog('GemmaLocalService.init vision flag changed — closing model');
      await _chat?.close();
      _chat = null;
      await _model!.close();
      _model = null;
    }
    _lastInitSupportImage = supportImage;

    if (_model == null) {
      if (reloadInferenceWeights) {
        chatInitLog('GemmaLocalService.init clearing XNNPACK caches');
        await clearTfliteXnnpackWeightCaches();
      }
      chatInitLog('GemmaLocalService.init getActiveModel…');
      _model = await _runtime.getActiveModel(
        maxTokens: 2048,
        supportImage: supportImage,
        maxNumImages: maxNumImages,
      );
      chatInitLog('GemmaLocalService.init getActiveModel done');
    }
    chatInitLog('GemmaLocalService.init closing prior chat session');
    await _chat?.close();
    _chat = null;
    chatInitLog('GemmaLocalService.init createChat…');
    _chat = await _model!.createChat(
      systemInstruction: systemInstruction,
      supportImage: supportImage,
      loraPath: loraPath,
    );
    chatInitLog('GemmaLocalService.init done');
  }

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
    chatInitLog('GemmaLocalService.close start');
    _pendingDeviceContextSituation = null;
    _lastInitSupportImage = null;
    await _chat?.close();
    _chat = null;
    await _model?.close();
    _model = null;
    chatInitLog('GemmaLocalService.close done');
  }
}
