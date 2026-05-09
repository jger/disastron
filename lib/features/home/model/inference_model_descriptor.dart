import 'package:disastron/features/home/model/predefined_models.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Resolved install target: explicit [ModelType] / [ModelFileType] (no UI string guessing).
class InferenceModelDescriptor {
  const InferenceModelDescriptor({
    required this.modelType,
    required this.fileType,
    this.presetId,
    this.displayTitle,
  });

  final ModelType modelType;
  final ModelFileType fileType;

  /// Set when source is a curated preset.
  final String? presetId;

  /// Human label for registry / UI.
  final String? displayTitle;

  /// Build from a preset row.
  factory InferenceModelDescriptor.fromPreset(PredefinedInferenceModel m) {
    return InferenceModelDescriptor(
      modelType: m.modelType,
      fileType: m.fileType,
      presetId: m.id,
      displayTitle: m.title,
    );
  }

  /// Resolve from URL or path: match HF repo to a preset when possible, else heuristics.
  factory InferenceModelDescriptor.fromUrlOrPath(String urlOrPath) {
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
          return InferenceModelDescriptor.fromPreset(m);
        }
      }
    }
    return InferenceModelDescriptor(
      modelType: modelTypeForInferenceSource(trimmed),
      fileType: modelFileTypeForUrl(trimmed),
    );
  }
}
