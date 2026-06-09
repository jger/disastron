import 'package:disastron/features/inference/domain/inference_model_helpers.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Hugging Face download access (from preset YAML `access`).
enum InferencePresetAccess {
  public,
  gated,
}

/// On-device runtime engine exposed to users.
enum InferenceBackend {
  litert,
  mediapipe;

  /// Short display label shown in chips and subtitles.
  String get displayLabel {
    switch (this) {
      case InferenceBackend.litert:
        return 'LiteRT';
      case InferenceBackend.mediapipe:
        return 'MediaPipe';
    }
  }
}

/// Curated preset `.task` / `.litertlm` model (user can still paste any URL).
class PredefinedInferenceModel {
  const PredefinedInferenceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    this.modelType = ModelType.gemmaIt,
    this.backend,
    this.requiresToken,
    this.sizeMb,
    this.access = InferencePresetAccess.gated,
    this.multimodal = false,
    this.supportsLora = false,
  });

  final String id;
  final String title;
  final String description;
  final String url;
  final ModelType modelType;

  /// Explicit backend from YAML, or null for user-installed models (derived from [fileType]).
  final InferenceBackend? backend;

  /// Approximate download size (MB), from bundled YAML.
  final int? sizeMb;

  /// Whether anonymous HF download works (`public`) or token is required (`gated`).
  final InferencePresetAccess access;

  /// When true, chat may offer photo attach when native vision init succeeds.
  final bool multimodal;

  /// When true, the model supports runtime dynamic LoRA loading.
  final bool supportsLora;

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

  /// Resolved runtime engine — uses explicit YAML value when present, otherwise
  /// inferred from the file extension (.litertlm → litert, .task/.bin → mediapipe).
  InferenceBackend get resolvedBackend =>
      backend ?? inferenceBackendForFileType(fileType);

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
