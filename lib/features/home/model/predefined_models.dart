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

/// Infer model family from a download URL or local file path (URL tab + file import).
ModelType modelTypeForInferenceSource(String urlOrPath) {
  final String trimmed = urlOrPath.trim();
  final Uri? parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasAuthority && parsed.pathSegments.length >= 2) {
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
  if (lower.contains('qwen3') ||
      lower.contains('qwen-3') ||
      lower.contains('qwen_3') ||
      lower.contains('qwen3.5')) {
    return ModelType.qwen3;
  }
  if (lower.contains('qwen')) {
    return ModelType.qwen;
  }
  if (lower.contains('gemma-4') || lower.contains('gemma4')) {
    return ModelType.gemma4;
  }
  return ModelType.gemmaIt;
}

/// Infer model family from URL when the UI does not ask (URL-only install tab).
ModelType modelTypeForInferenceUrl(String url) => modelTypeForInferenceSource(url);

/// Gemma-family installs may use a Hugging Face token for gated URLs.
bool inferenceModelTypeUsesHuggingFaceToken(ModelType modelType) {
  return modelType == ModelType.gemmaIt ||
      modelType == ModelType.gemma4 ||
      modelType == ModelType.functionGemma;
}

/// Curated public `.task` / `.litertlm` models (user can still paste any URL).
class PredefinedInferenceModel {
  const PredefinedInferenceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    this.modelType = ModelType.gemmaIt,
    this.requiresToken,
  });

  final String id;
  final String title;
  final String description;
  final String url;
  final ModelType modelType;

  /// When non-null, overrides [inferenceModelTypeUsesHuggingFaceToken] for downloads.
  final bool? requiresToken;

  /// Whether install UI must collect an HF token before network download.
  bool get requiresHuggingFaceToken =>
      requiresToken ?? inferenceModelTypeUsesHuggingFaceToken(modelType);

  ModelFileType get fileType => modelFileTypeForUrl(url);
}

/// Smallest storage-friendly Gemma preset (used for dashboard CTA).
const String kSmallestStoragePresetId = 'gemma3_270m_q8';

PredefinedInferenceModel get kSmallestStorageDownloadPreset =>
    kPredefinedInferenceModels.firstWhere(
      (PredefinedInferenceModel m) => m.id == kSmallestStoragePresetId,
    );

const List<PredefinedInferenceModel> kPredefinedInferenceModels = <PredefinedInferenceModel>[
  PredefinedInferenceModel(
    id: 'qwen25_05b',
    title: 'Qwen 2.5 0.5B Instruct',
    description: 'Compact multilingual instruct model.',
    url: 'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    modelType: ModelType.qwen,
    requiresToken: false,
  ),
  PredefinedInferenceModel(
    id: 'qwen35_08b_litertlm',
    title: 'Qwen 3.5 0.8B (LiteRT)',
    description: 'Public LiteRT export; very large download (~1.1GB), multimodal bundle.',
    url: 'https://huggingface.co/LudwigBanach/Qwen3.5-0.8B-LiteRT/resolve/main/qwen35_mm_q8_ekv2048.litertlm',
    modelType: ModelType.qwen3,
    requiresToken: false,
  ),
  PredefinedInferenceModel(
    id: 'gemma3_270m_q8',
    title: 'Gemma 3 270M IT (q8)',
    description: 'Smallest preset; good for low storage.',
    url: 'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task',
    requiresToken: false,
  ),
  PredefinedInferenceModel(
    id: 'gemma3_1b_int4',
    title: 'Gemma 3 1B IT (int4)',
    description: 'Balanced quality vs size (~0.5GB class).',
    url: 'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
    requiresToken: false,
  ),
  PredefinedInferenceModel(
    id: 'gemma3n_e2b_int4',
    title: 'Gemma 3n E2B IT (int4)',
    description: 'Multimodal-capable family (larger download).',
    url: 'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
  ),
  PredefinedInferenceModel(
    id: 'gemma4_e2b_litertlm',
    title: 'Gemma 4 E2B IT (LiteRT-LM)',
    description: 'Multimodal (text, image, audio); large download (~2.4GB).',
    url:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    modelType: ModelType.gemma4,
    requiresToken: false,
  ),
  PredefinedInferenceModel(
    id: 'gemma4_e4b_litertlm',
    title: 'Gemma 4 E4B IT (LiteRT-LM)',
    description: 'Larger Gemma 4 variant; multimodal; ~4.3GB.',
    url:
        'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
    modelType: ModelType.gemma4,
    requiresToken: false,
  ),
];
