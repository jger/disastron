import 'dart:async';

import 'package:disastron/features/home/model/huggingface_token_provider.dart';
import 'package:disastron/features/home/model/model_install_prefs.dart';
import 'package:disastron/features/home/model/predefined_models.dart'
    show modelFileTypeForUrl, modelTypeForInferenceSource;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_gemma_model_provider.g.dart';

enum LocalGemmaPhase { notInstalled, installing, ready, error }

class LocalGemmaModelUi {
  const LocalGemmaModelUi({
    required this.phase,
    this.progress = 0,
    this.errorMessage,
    this.isGated403 = false,
    this.gatedModelPageUrl,
  });

  final LocalGemmaPhase phase;
  final int progress;
  final String? errorMessage;
  final bool isGated403;
  final String? gatedModelPageUrl;

  bool get isReady => phase == LocalGemmaPhase.ready;
}

ModelFileType modelFileTypeForPath(String path) {
  return modelFileTypeForUrl(Uri.file(path).toString());
}

String _basenameFromStored(String urlOrPath) {
  final Uri uri =
      urlOrPath.contains('://') ? Uri.parse(urlOrPath) : Uri.file(urlOrPath);
  if (uri.pathSegments.isEmpty) {
    return urlOrPath;
  }
  return uri.pathSegments.last;
}

String? _hfModelPageFromDownloadUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    return null;
  }
  if (!uri.host.toLowerCase().contains('huggingface.co')) {
    return null;
  }
  final List<String> segs = uri.pathSegments;
  if (segs.length < 2) {
    return null;
  }
  return 'https://huggingface.co/${segs[0]}/${segs[1]}';
}

@Riverpod(keepAlive: true)
class LocalGemmaModel extends _$LocalGemmaModel {
  final ModelInstallPrefs _installPrefs = ModelInstallPrefs();
  bool _restoreInFlight = false;

  @override
  LocalGemmaModelUi build() {
    final bool active = FlutterGemma.hasActiveModel();
    if (!active && !kIsWeb) {
      unawaited(_tryRestoreModel());
    }
    return LocalGemmaModelUi(
      phase: active ? LocalGemmaPhase.ready : LocalGemmaPhase.notInstalled,
    );
  }

  void refreshFromEngine() {
    if (state.phase == LocalGemmaPhase.installing) {
      return;
    }
    state = LocalGemmaModelUi(
      phase: FlutterGemma.hasActiveModel()
          ? LocalGemmaPhase.ready
          : LocalGemmaPhase.notInstalled,
    );
  }

  /// Sets installing phase at 0% so UI shows progress before network work (dialogs, etc.).
  void beginInstallFlow() {
    state = const LocalGemmaModelUi(phase: LocalGemmaPhase.installing);
  }

  /// Restores UI after user cancels before installFromNetwork returns real progress.
  void abortInstallAttempt() {
    if (state.phase != LocalGemmaPhase.installing || state.progress > 0) {
      return;
    }
    state = LocalGemmaModelUi(
      phase: FlutterGemma.hasActiveModel()
          ? LocalGemmaPhase.ready
          : LocalGemmaPhase.notInstalled,
    );
  }

  Future<void> _tryRestoreModel() async {
    if (kIsWeb) {
      return;
    }
    if (FlutterGemma.hasActiveModel()) {
      return;
    }
    if (_restoreInFlight) {
      return;
    }
    _restoreInFlight = true;
    try {
      final ModelInstallRecord? record = await _installPrefs.read();
      if (record == null) {
        return;
      }
      final String filename = _basenameFromStored(record.urlOrPath);
      final bool installed = await FlutterGemma.isModelInstalled(filename);
      if (!installed) {
        return;
      }
      final String dir = (await getApplicationDocumentsDirectory()).path;
      final String localPath = p.join(dir, filename);
      state = const LocalGemmaModelUi(phase: LocalGemmaPhase.installing);
      try {
        await FlutterGemma.installModel(
          modelType: record.modelType,
          fileType: record.fileType,
        )
            .fromFile(localPath)
            .withProgress((int progress) {
              state = LocalGemmaModelUi(
                phase: LocalGemmaPhase.installing,
                progress: progress,
              );
            })
            .install();
        state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
      } on Object catch (e) {
        state = LocalGemmaModelUi(
          phase: LocalGemmaPhase.error,
          errorMessage: e.toString(),
        );
      }
    } finally {
      _restoreInFlight = false;
    }
  }

  Future<void> installFromFile(String path) async {
    state = const LocalGemmaModelUi(phase: LocalGemmaPhase.installing);
    try {
      final ModelFileType fileType = modelFileTypeForPath(path);
      final ModelType modelType = modelTypeForInferenceSource(path);
      await FlutterGemma.installModel(
        modelType: modelType,
        fileType: fileType,
      )
          .fromFile(path)
          .withProgress((int progress) {
            state = LocalGemmaModelUi(phase: LocalGemmaPhase.installing, progress: progress);
          })
          .install();
      await _installPrefs.save(urlOrPath: path, modelType: modelType, fileType: fileType);
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
      final String? effectiveToken = (trimmed != null && trimmed.isNotEmpty)
          ? trimmed
          : await ref.read(huggingfaceTokenProvider.future);
      await FlutterGemma.installModel(
        modelType: resolvedModelType,
        fileType: resolvedFileType,
      )
          .fromNetwork(url, token: effectiveToken)
          .withProgress((int progress) {
            state = LocalGemmaModelUi(phase: LocalGemmaPhase.installing, progress: progress);
          })
          .install();
      await _installPrefs.save(
        urlOrPath: url,
        modelType: resolvedModelType,
        fileType: resolvedFileType,
      );
      state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
    } on Object catch (e) {
      final String msg = e.toString();
      final bool is403 =
          msg.contains('403') || msg.toLowerCase().contains('forbidden');
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: msg,
        isGated403: is403,
        gatedModelPageUrl: is403 ? _hfModelPageFromDownloadUrl(url) : null,
      );
    }
  }
}
