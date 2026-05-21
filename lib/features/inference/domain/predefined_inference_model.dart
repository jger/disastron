import 'package:disastron/features/inference/domain/inference_model_helpers.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Hugging Face download access (from preset YAML `access`).
enum InferencePresetAccess {
  public,
  gated,
}

/// Curated preset `.task` / `.litertlm` model (user can still paste any URL).
class PredefinedInferenceModel {
  const PredefinedInferenceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    this.modelType = ModelType.gemmaIt,
    this.requiresToken,
    this.sizeMb,
    this.access = InferencePresetAccess.gated,
    this.multimodal = false,
  });

  final String id;
  final String title;
  final String description;
  final String url;
  final ModelType modelType;

  /// Approximate download size (MB), from bundled YAML.
  final int? sizeMb;

  /// Whether anonymous HF download works (`public`) or token is required (`gated`).
  final InferencePresetAccess access;

  /// When true, chat may offer photo attach when native vision init succeeds.
  final bool multimodal;

  /// When non-null, overrides [inferenceModelTypeUsesHuggingFaceToken] for downloads.
  final bool? requiresToken;

  /// Whether install UI must collect an HF token before network download.
  bool get requiresHuggingFaceToken {
    if (requiresToken != null) {
      return requiresToken!;
    }
    if (access == InferencePresetAccess.public) {
      return false;
    }
    return inferenceModelTypeUsesHuggingFaceToken(modelType);
  }

  ModelFileType get fileType => modelFileTypeForUrl(url);

  /// One-line summary for list tiles and download dialogs.
  String get downloadMetadataLine {
    final List<String> parts = <String>[];
    if (sizeMb != null) {
      parts.add('~$sizeMb MB download');
    }
    parts.add(
      access == InferencePresetAccess.public
          ? 'Public on Hugging Face'
          : 'HF token + Gemma license',
    );
    if (multimodal) {
      parts.add('Photos in chat');
    }
    return parts.join(' · ');
  }
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
