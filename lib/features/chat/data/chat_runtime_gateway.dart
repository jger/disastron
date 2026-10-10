import 'package:flutter_edge_ai/flutter_edge_ai.dart';

/// Abstraction over the active inference engine (currently [FlutterEdgeAi] only).
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

class FlutterEdgeAiChatRuntimeGateway implements ChatRuntimeGateway {
  const FlutterEdgeAiChatRuntimeGateway();

  @override
  Future<InferenceModel> getActiveModel({
    required int maxTokens,
    bool supportImage = false,
    int? maxNumImages,
    int? maxConcurrentSessions,
  }) => FlutterEdgeAi.getActiveModel(
    maxTokens: maxTokens,
    supportImage: supportImage,
    maxNumImages: maxNumImages,
    maxConcurrentSessions: maxConcurrentSessions,
  );

  @override
  ModelType? activeModelType() {
    final ModelSpec? spec =
        FlutterEdgeAiPlugin.instance.modelManager.activeInferenceModel;
    return spec is InferenceModelSpec ? spec.modelType : null;
  }

  @override
  bool hasActiveModel() => FlutterEdgeAi.hasActiveModel();
}
