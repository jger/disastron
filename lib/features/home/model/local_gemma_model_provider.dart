import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_gemma_model_provider.g.dart';

enum LocalGemmaPhase { notInstalled, installing, ready, error }

class LocalGemmaModelUi {
  const LocalGemmaModelUi({
    required this.phase,
    this.progress = 0,
    this.errorMessage,
  });

  final LocalGemmaPhase phase;
  final int progress;
  final String? errorMessage;

  bool get isReady => phase == LocalGemmaPhase.ready;
}

ModelFileType modelFileTypeForPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.bin') || lower.endsWith('.tflite')) {
    return ModelFileType.binary;
  }
  if (lower.endsWith('.litertlm')) {
    return ModelFileType.litertlm;
  }
  return ModelFileType.task;
}

@Riverpod(keepAlive: true)
class LocalGemmaModel extends _$LocalGemmaModel {
  @override
  LocalGemmaModelUi build() {
    return LocalGemmaModelUi(
      phase: FlutterGemma.hasActiveModel()
          ? LocalGemmaPhase.ready
          : LocalGemmaPhase.notInstalled,
    );
  }

  void refreshFromEngine() {
    state = LocalGemmaModelUi(
      phase: FlutterGemma.hasActiveModel()
          ? LocalGemmaPhase.ready
          : LocalGemmaPhase.notInstalled,
    );
  }

  Future<void> installFromFile(String path) async {
    state = const LocalGemmaModelUi(phase: LocalGemmaPhase.installing);
    try {
      final fileType = modelFileTypeForPath(path);
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: fileType,
      )
          .fromFile(path)
          .withProgress((int p) {
            state = LocalGemmaModelUi(phase: LocalGemmaPhase.installing, progress: p);
          })
          .install();
      state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
    } on Object catch (e) {
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> installFromNetwork(String url) async {
    state = const LocalGemmaModelUi(phase: LocalGemmaPhase.installing);
    try {
      final path = Uri.parse(url).path.toLowerCase();
      final fileType = modelFileTypeForPath(path);
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: fileType,
      )
          .fromNetwork(url)
          .withProgress((int p) {
            state = LocalGemmaModelUi(phase: LocalGemmaPhase.installing, progress: p);
          })
          .install();
      state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
    } on Object catch (e) {
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: e.toString(),
      );
    }
  }
}
