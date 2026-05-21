import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Static hints for which **installed** models *may* support vision.
///
/// Chat enables image attach only after native init with `supportImage`
/// succeeds; otherwise the session falls back to text-only inference.
const Set<String> kVisionCapablePresetIds = <String>{
  'gemma3_270m_q8',
  'gemma3_270m_q4',
  'gemma3_1b_int4',
  'gemma3n_e2b_int4',
  'gemma4_e2b_litertlm',
  'gemma4_e4b_litertlm',
};

/// Whether the active / selected inference model should enable flutter_gemma vision.
bool inferenceModelSupportsVision({
  required ModelType modelType,
  String? presetId,
  String? sourceUrlOrPath,
}) {
  if (modelType == ModelType.gemma4) {
    return true;
  }
  if (presetId != null && kVisionCapablePresetIds.contains(presetId)) {
    return true;
  }
  final String s = (sourceUrlOrPath ?? '').toLowerCase();
  if (s.contains('gemma-3n') ||
      s.contains('gemma3n') ||
      s.contains('gemma-4') ||
      s.contains('gemma4')) {
    return true;
  }
  return false;
}

/// Vision support for the library row marked active in [snapshot].
bool activeRegistryEntrySupportsVision(ModelRegistrySnapshot snapshot) {
  final String? id = snapshot.activeEntryId;
  if (id == null) {
    return false;
  }
  final InstalledModelEntry? e = snapshot.entryById(id);
  if (e == null) {
    return false;
  }
  return inferenceModelSupportsVision(
    modelType: e.modelType,
    presetId: e.presetId,
    sourceUrlOrPath: e.sourceUrlOrPath,
  );
}
