import 'package:disastron/features/home/model/model_registry_store.dart';
import 'package:disastron/features/home/model/predefined_models.dart';
import 'package:flutter_gemma/core/domain/model_source.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Readable label + detail for the active inference model (from plugin state).
class ActiveInferenceModelSummary {
  const ActiveInferenceModelSummary({
    required this.label,
    required this.detailLine,
  });

  final String label;
  final String detailLine;
}

ActiveInferenceModelSummary? _summaryFromPlugin() {
  final ModelSpec? raw = FlutterGemmaPlugin.instance.modelManager.activeInferenceModel;
  if (raw is! InferenceModelSpec) {
    return null;
  }
  final InferenceModelSpec spec = raw;

  String label = spec.name;
  final ModelSource src = spec.modelSource;
  if (src is NetworkSource) {
    for (final PredefinedInferenceModel m in kPredefinedInferenceModels) {
      if (m.url == src.url) {
        label = m.title;
        break;
      }
    }
  }

  final String file = spec.files.isNotEmpty ? spec.files.first.filename : '';
  final String detail =
      '${spec.modelType.name} · ${spec.fileType.name}${file.isEmpty ? '' : ' · $file'}';

  return ActiveInferenceModelSummary(label: label, detailLine: detail);
}

/// Prefer registry entry display title when it matches the active plugin model.
ActiveInferenceModelSummary? readActiveInferenceSummary({
  ModelRegistrySnapshot? registry,
}) {
  final ActiveInferenceModelSummary? plugin = _summaryFromPlugin();
  if (registry == null || registry.activeEntryId == null) {
    return plugin;
  }
  final InstalledModelEntry? entry =
      registry.entryById(registry.activeEntryId!);
  if (entry == null) {
    return plugin;
  }
  final String detail = plugin?.detailLine ??
      '${entry.modelType.name} · ${entry.fileType.name}';
  return ActiveInferenceModelSummary(
    label: entry.displayTitle,
    detailLine: detail,
  );
}
