import 'package:flutter_gemma/flutter_gemma.dart';

const String kDisasterSystemInstruction =
    'You are Disastron, a concise offline assistant for emergencies: wars, natural disasters, '
    'transport accidents, fires, medical crises. Give practical, calm, step-by-step guidance. '
    'If information is uncertain, say so. Do not claim real-time data you cannot have offline. '
    'Prioritize safety, evacuation, shelter, first aid basics, and contacting local authorities when possible.';

class GemmaLocalService {
  InferenceModel? _model;
  InferenceChat? _chat;

  bool get isInitialized => _chat != null;

  Future<void> init() async {
    if (_chat != null) {
      return;
    }
    _model = await FlutterGemma.getActiveModel(maxTokens: 2048);
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
