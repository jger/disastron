import 'package:flutter_gemma/flutter_gemma.dart';

/// Abstraction over the active inference engine (currently [FlutterGemma] only).
abstract class ChatRuntimeGateway {
  Future<InferenceModel> getActiveModel({
    required int maxTokens,
    bool supportImage = false,
    int? maxNumImages,
    int? maxConcurrentSessions,
  });

  /// The active model's real [ModelType], or null when none is installed.
  ///
  /// [InferenceModel.createChat] defaults an omitted `modelType` to
  /// [ModelType.gemmaIt], which silently puts a gemma4 model on gemmaIt's
  /// thinking-filter and function-call-parsing branches.
  ModelType? activeModelType();

  bool hasActiveModel();
}

class FlutterGemmaChatRuntimeGateway implements ChatRuntimeGateway {
  const FlutterGemmaChatRuntimeGateway();

  @override
  Future<InferenceModel> getActiveModel({
    required int maxTokens,
    bool supportImage = false,
    int? maxNumImages,
    int? maxConcurrentSessions,
  }) => FlutterGemma.getActiveModel(
    maxTokens: maxTokens,
    supportImage: supportImage,
    maxNumImages: maxNumImages,
    maxConcurrentSessions: maxConcurrentSessions,
  );

  @override
  ModelType? activeModelType() {
    final ModelSpec? spec =
        FlutterGemmaPlugin.instance.modelManager.activeInferenceModel;
    return spec is InferenceModelSpec ? spec.modelType : null;
  }

  @override
  bool hasActiveModel() => FlutterGemma.hasActiveModel();
}
