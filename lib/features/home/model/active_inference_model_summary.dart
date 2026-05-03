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

ActiveInferenceModelSummary? readActiveInferenceSummary() {
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
