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
  });

  final String id;
  final String title;
  final String description;
  final String url;
  final ModelType modelType;

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
  ),
  PredefinedInferenceModel(
    id: 'qwen35_08b_litertlm',
    title: 'Qwen 3.5 0.8B (LiteRT)',
    description: 'Public LiteRT export; very large download (~1.1GB), multimodal bundle.',
    url: 'https://huggingface.co/LudwigBanach/Qwen3.5-0.8B-LiteRT/resolve/main/qwen35_mm_q8_ekv2048.litertlm',
    modelType: ModelType.qwen3,
  ),
  PredefinedInferenceModel(
    id: 'gemma3_270m_q8',
    title: 'Gemma 3 270M IT (q8)',
    description: 'Smallest preset; good for low storage.',
    url: 'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task',
  ),
  PredefinedInferenceModel(
    id: 'gemma3_1b_int4',
    title: 'Gemma 3 1B IT (int4)',
    description: 'Balanced quality vs size (~0.5GB class).',
    url: 'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
  ),
  PredefinedInferenceModel(
    id: 'gemma3n_e2b_int4',
    title: 'Gemma 3n E2B IT (int4)',
    description: 'Multimodal-capable family (larger download).',
    url: 'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
  ),
];
