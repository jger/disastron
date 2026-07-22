import 'package:disastron/features/inference/domain/predefined_inference_model.dart';
import 'package:disastron/features/inference/domain/predefined_inference_models_state.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

ModelFileType modelFileTypeForUrl(String url) {
  final String path = Uri.parse(url).path.toLowerCase();
  if (path.endsWith('.bin') || path.endsWith('.tflite')) {
    return ModelFileType.binary;
  }
  if (path.endsWith('.litertlm')) {
    return ModelFileType.litertlm;
  }
  return ModelFileType.task;
}

/// Maps [ModelFileType] to the runtime engine it uses.
/// `.litertlm` → LiteRT; `.task` and `.bin` → MediaPipe.
InferenceBackend inferenceBackendForFileType(ModelFileType fileType) {
  switch (fileType) {
    case ModelFileType.litertlm:
      return InferenceBackend.litert;
    case ModelFileType.task:
    case ModelFileType.binary:
      return InferenceBackend.mediapipe;
    case ModelFileType.builtIn:
      // OS-native models (Gemini Nano, Apple Foundation Models) have no file
      // and run on neither MediaPipe nor LiteRT. They never originate from a
      // URL/path, so [modelFileTypeForUrl] never yields this value here.
      throw ArgumentError.value(
        fileType,
        'fileType',
        'builtIn models have no downloadable file backend',
      );
  }
}

/// Infer model family from a download URL or local file path (URL tab + file import).
ModelType modelTypeForInferenceSource(String urlOrPath) {
  final String trimmed = urlOrPath.trim();
  final Uri? parsed = Uri.tryParse(trimmed);
  if (parsed != null &&
      parsed.hasAuthority &&
      parsed.pathSegments.length >= 2) {
    for (final PredefinedInferenceModel m in kPredefinedInferenceModels) {
      final Uri? presetUri = Uri.tryParse(m.url);
      if (presetUri == null ||
          presetUri.pathSegments.length < 2 ||
          parsed.host != presetUri.host) {
        continue;
      }
      if (parsed.pathSegments[0] == presetUri.pathSegments[0] &&
          parsed.pathSegments[1] == presetUri.pathSegments[1]) {
        return m.modelType;
      }
    }
  }

  final String lower = trimmed.toLowerCase();
  if (lower.contains('gemma-4') || lower.contains('gemma4')) {
    return ModelType.gemma4;
  }
  return ModelType.gemmaIt;
}

/// Infer model family from URL when the UI does not ask (URL-only install tab).
ModelType modelTypeForInferenceUrl(String url) =>
    modelTypeForInferenceSource(url);

/// Gemma-family installs may use a Hugging Face token for gated URLs.
bool inferenceModelTypeUsesHuggingFaceToken(ModelType modelType) {
  return modelType == ModelType.gemmaIt ||
      modelType == ModelType.gemma4 ||
      modelType == ModelType.functionGemma;
}
