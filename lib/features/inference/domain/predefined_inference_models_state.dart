import 'package:disastron/features/inference/domain/predefined_inference_model.dart';

PredefinedInferenceModelsCatalog? _catalog;

bool get isPredefinedInferenceModelsCatalogLoaded => _catalog != null;

void _requireCatalogLoaded() {
  if (_catalog == null) {
    throw StateError(
      'Predefined inference models not loaded. '
      'Call ensurePredefinedInferenceModelsLoaded() during app startup.',
    );
  }
}

/// Bundled preset catalog (from assets/data/inference_models.yaml).
List<PredefinedInferenceModel> get kPredefinedInferenceModels {
  _requireCatalogLoaded();
  return _catalog!.models;
}

/// Default/smallest preset id — `default_preset_id` in inference_models.yaml (SSOT).
String get kDefaultInferencePresetId {
  _requireCatalogLoaded();
  return _catalog!.defaultPresetId;
}

/// Default/smallest preset model — resolved from YAML at load time.
PredefinedInferenceModel get kDefaultInferencePreset {
  _requireCatalogLoaded();
  return _catalog!.defaultPreset;
}

PredefinedInferenceModel? presetInferenceModelById(String id) {
  if (_catalog == null) {
    return null;
  }
  for (final PredefinedInferenceModel m in kPredefinedInferenceModels) {
    if (m.id == id) {
      return m;
    }
  }
  return null;
}

/// Registers catalog loaded from assets (app bootstrap).
void registerPredefinedInferenceModelsCatalog(
  PredefinedInferenceModelsCatalog catalog,
) {
  _catalog = catalog;
}

/// Test-only: reset catalog state.
void debugResetPredefinedInferenceModelsCatalog() {
  _catalog = null;
}
