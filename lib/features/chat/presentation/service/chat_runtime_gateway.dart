import 'package:flutter_gemma/flutter_gemma.dart';

/// Abstraction over the active inference engine (currently [FlutterGemma] only).
abstract class ChatRuntimeGateway {
  Future<InferenceModel> getActiveModel({
    required int maxTokens,
    bool supportImage = false,
    int? maxNumImages,
  });

  bool hasActiveModel();
}

class FlutterGemmaChatRuntimeGateway implements ChatRuntimeGateway {
  const FlutterGemmaChatRuntimeGateway();

  @override
  Future<InferenceModel> getActiveModel({
    required int maxTokens,
    bool supportImage = false,
    int? maxNumImages,
  }) => FlutterGemma.getActiveModel(
    maxTokens: maxTokens,
    supportImage: supportImage,
    maxNumImages: maxNumImages,
  );

  @override
  bool hasActiveModel() => FlutterGemma.hasActiveModel();
}
