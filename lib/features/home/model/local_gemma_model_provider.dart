import 'package:disastron/features/home/model/huggingface_token_provider.dart';
import 'package:disastron/features/home/model/predefined_models.dart'
    show inferenceModelTypeUsesHuggingFaceToken, modelFileTypeForUrl;
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
  return modelFileTypeForUrl(Uri.file(path).toString());
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
      final ModelFileType fileType = modelFileTypeForPath(path);
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

  /// [token] overrides saved store; otherwise uses [huggingfaceTokenProvider].
  Future<void> installFromNetwork(
    String url, {
    String? token,
    ModelType? modelType,
    ModelFileType? fileType,
  }) async {
    state = const LocalGemmaModelUi(phase: LocalGemmaPhase.installing);
    try {
      final String? trimmed = token?.trim();
      final ModelFileType resolvedFileType = fileType ?? modelFileTypeForUrl(url);
      final ModelType resolvedModelType = modelType ?? ModelType.gemmaIt;
      final bool useHfToken = inferenceModelTypeUsesHuggingFaceToken(resolvedModelType);
      final String? effectiveToken = useHfToken
          ? ((trimmed != null && trimmed.isNotEmpty)
              ? trimmed
              : await ref.read(huggingfaceTokenProvider.future))
          : null;
      await FlutterGemma.installModel(
        modelType: resolvedModelType,
        fileType: resolvedFileType,
      )
          .fromNetwork(url, token: effectiveToken)
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
