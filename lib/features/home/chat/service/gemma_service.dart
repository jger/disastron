import 'package:disastron/features/home/chat/service/chat_runtime_gateway.dart';
import 'package:disastron/features/home/chat/service/xnnpack_cache_cleanup.dart';
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

  bool get isInitialized => _chat != null;

  Future<void> init() async {
    if (_chat != null) {
      return;
    }
    await clearTfliteXnnpackWeightCaches();
    _model = await _runtime.getActiveModel(maxTokens: 2048);
    _chat = await _model!.createChat(
      systemInstruction: kDisasterSystemInstruction,
    );
  }

  Stream<ModelResponse> processMessageAsync(Message userMessage) async* {
    final InferenceChat chat = _chat!;
    await chat.addQuery(userMessage);
    yield* chat.generateChatResponseAsync();
  }

  Future<void> close() async {
    await _model?.close();
    _model = null;
    _chat = null;
  }
}
