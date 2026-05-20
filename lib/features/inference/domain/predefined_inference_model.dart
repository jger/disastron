import 'package:disastron/features/inference/domain/inference_model_helpers.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Curated preset `.task` / `.litertlm` model (user can still paste any URL).
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

/// Parsed preset catalog from bundled YAML ([defaultPresetId] is SSOT in YAML).
class PredefinedInferenceModelsCatalog {
  const PredefinedInferenceModelsCatalog({
    required this.defaultPresetId,
    required this.defaultPreset,
    required this.models,
  });

  /// `default_preset_id` from assets/data/inference_models.yaml.
  final String defaultPresetId;

  /// Resolved entry for [defaultPresetId] (validated at parse time).
  final PredefinedInferenceModel defaultPreset;
  final List<PredefinedInferenceModel> models;
}
