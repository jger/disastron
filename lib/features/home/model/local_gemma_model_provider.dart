import 'dart:async';

import 'package:disastron/features/home/model/huggingface_token_provider.dart';
import 'package:disastron/features/home/model/model_file_export.dart';
import 'package:disastron/features/home/model/model_install_activity_kind.dart';
import 'package:disastron/features/home/model/model_install_domain_error.dart';
import 'package:disastron/features/home/model/model_install_orchestrator.dart';
import 'package:disastron/features/home/model/model_operation_state.dart';
import 'package:disastron/features/home/model/model_registry_provider.dart';
import 'package:disastron/features/home/model/model_registry_store.dart';
import 'package:disastron/features/home/model/predefined_models.dart'
    show
        PredefinedInferenceModel,
        modelFileTypeForUrl,
        modelTypeForInferenceSource,
        presetInferenceModelById;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_gemma_model_provider.g.dart';

enum LocalGemmaPhase { notInstalled, installing, ready, error }

class LocalGemmaModelUi {
  const LocalGemmaModelUi({
    required this.phase,
    this.progress = 0,
    this.activity = ModelInstallActivityKind.unknown,
    this.errorMessage,
    this.isGated403 = false,
    this.gatedModelPageUrl,
    this.lastFailedDownloadUrl,
  });

  final LocalGemmaPhase phase;
  final int progress;
  final ModelInstallActivityKind activity;
  final String? errorMessage;
  final bool isGated403;
  final String? gatedModelPageUrl;
  final String? lastFailedDownloadUrl;

  bool get isReady => phase == LocalGemmaPhase.ready;

  /// Progress update while keeping [activity] and clearing error-only fields.
  LocalGemmaModelUi withInstallProgress(int newProgress) {
    return LocalGemmaModelUi(
      phase: LocalGemmaPhase.installing,
      progress: newProgress,
      activity: activity,
    );
  }

  ModelInstallSurfacePhase? get installSurface {
    if (phase != LocalGemmaPhase.installing) {
      return null;
    }
    return progress > 0
        ? ModelInstallSurfacePhase.transferring
        : ModelInstallSurfacePhase.preparing;
  }
}

ModelFileType modelFileTypeForPath(String path) {
  return modelFileTypeForUrl(Uri.file(path).toString());
}

@Riverpod(keepAlive: true)
class LocalGemmaModel extends _$LocalGemmaModel {
  final ModelInstallOrchestrator _orchestrator =
      ModelInstallOrchestrator(registry: ModelRegistryStore());
  bool _restoreInFlight = false;

  /// Bumps when a new install/preflight starts or user cancels, so stale
  /// plugin callbacks don't overwrite UI.
  int _installEpoch = 0;

  CancelToken? _installCancelToken;

  void _invalidateRegistry() {
    ref.invalidate(modelRegistrySnapshotProvider);
  }

  bool _isInstallEpochCurrent(int epoch) => epoch == _installEpoch;

  void _syncUiToEngine() {
    state = LocalGemmaModelUi(
      phase: FlutterGemma.hasActiveModel()
          ? LocalGemmaPhase.ready
          : LocalGemmaPhase.notInstalled,
    );
  }

  /// Cancels in-flight download/install token (if any) and invalidates epoch.
  void _bumpEpochAndCancelToken([String reason = 'Cancelled']) {
    _installCancelToken?.cancel(reason);
    _installCancelToken = null;
    _installEpoch++;
  }

  /// Preflight UI only (metered confirm / token). No [CancelToken] yet.
  void beginInstallFlow(ModelInstallActivityKind kind) {
    _bumpEpochAndCancelToken('New install flow');
    state = LocalGemmaModelUi(
      phase: LocalGemmaPhase.installing,
      activity: kind,
    );
  }

  void abortInstallAttempt() {
    if (state.phase != LocalGemmaPhase.installing) {
      return;
    }
    _bumpEpochAndCancelToken('Preflight aborted');
    _syncUiToEngine();
  }

  /// User-facing cancel: stops network/file install via [CancelToken] and
  /// leaves UI immediately (late completions ignored).
  void requestInstallCancel() {
    if (state.phase != LocalGemmaPhase.installing) {
      return;
    }
    _bumpEpochAndCancelToken('User cancelled');
    _syncUiToEngine();
  }

  /// Starts a tracked install session with a fresh [CancelToken].
  int _beginTrackedInstall(ModelInstallActivityKind activity) {
    _bumpEpochAndCancelToken('Starting install');
    final int epoch = _installEpoch;
    _installCancelToken = CancelToken();
    state = LocalGemmaModelUi(
      phase: LocalGemmaPhase.installing,
      activity: activity,
    );
    return epoch;
  }

  void _clearInstallTokenIfSame(CancelToken? token) {
    if (token != null && identical(_installCancelToken, token)) {
      _installCancelToken = null;
    }
  }

  @override
  LocalGemmaModelUi build() {
    final bool active = FlutterGemma.hasActiveModel();
    if (!active && !kIsWeb) {
      unawaited(_tryRestoreModel());
    } else if (active) {
      unawaited(_orchestrator.reconcileActiveWithPluginIfPossible());
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
    if (FlutterGemma.hasActiveModel()) {
      unawaited(_orchestrator.reconcileActiveWithPluginIfPossible());
      _invalidateRegistry();
    }
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
      final ColdStartRestoreResult result =
          await _orchestrator.tryRestoreOnColdStart(
        onProgress: (int progress) {
          if (state.activity != ModelInstallActivityKind.restoreSaved) {
            return;
          }
          state = state.withInstallProgress(progress);
        },
        onRestoreBegins: () {
          state = const LocalGemmaModelUi(
            phase: LocalGemmaPhase.installing,
            activity: ModelInstallActivityKind.restoreSaved,
          );
        },
      );
      if (!result.attempted) {
        if (state.activity == ModelInstallActivityKind.restoreSaved) {
          state = LocalGemmaModelUi(
            phase: FlutterGemma.hasActiveModel()
                ? LocalGemmaPhase.ready
                : LocalGemmaPhase.notInstalled,
          );
        }
        return;
      }
      if (result.error != null) {
        if (state.activity != ModelInstallActivityKind.restoreSaved) {
          return;
        }
        final ModelInstallDomainError err = result.error!;
        state = LocalGemmaModelUi(
          phase: LocalGemmaPhase.error,
          errorMessage: err.message,
          isGated403: err.isGated403,
          gatedModelPageUrl: err.gatedModelPageUrl,
        );
        return;
      }
      if (FlutterGemma.hasActiveModel()) {
        if (state.activity == ModelInstallActivityKind.restoreSaved) {
          state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
          _invalidateRegistry();
        }
      } else if (state.activity == ModelInstallActivityKind.restoreSaved) {
        state = const LocalGemmaModelUi(phase: LocalGemmaPhase.notInstalled);
      }
    } finally {
      _restoreInFlight = false;
    }
  }

  Future<void> installFromFile(String path) async {
    final int epoch = _beginTrackedInstall(
      ModelInstallActivityKind.importLocalFile,
    );
    final CancelToken? cancelToken = _installCancelToken;
    try {
      await _orchestrator.installFromFile(
        path,
        cancelToken: cancelToken,
        onProgress: (int progress) {
          if (!_isInstallEpochCurrent(epoch)) {
            return;
          }
          state = state.withInstallProgress(progress);
        },
      );
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
      _invalidateRegistry();
    } on Object catch (e) {
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      if (CancelToken.isCancel(e)) {
        _syncUiToEngine();
        return;
      }
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: e.toString(),
      );
    } finally {
      _clearInstallTokenIfSame(cancelToken);
    }
  }

  /// [token] overrides saved store; otherwise uses [huggingfaceTokenProvider].
  Future<void> installFromNetwork(
    String url, {
    String? token,
    ModelType? modelType,
    ModelFileType? fileType,
  }) async {
    final int epoch = _beginTrackedInstall(
      ModelInstallActivityKind.downloadNetwork,
    );
    final CancelToken? cancelToken = _installCancelToken;
    try {
      final String? trimmed = token?.trim();
      final ModelFileType resolvedFileType = fileType ?? modelFileTypeForUrl(url);
      final ModelType resolvedModelType =
          modelType ?? modelTypeForInferenceSource(url);
      final String? effectiveToken = (trimmed != null && trimmed.isNotEmpty)
          ? trimmed
          : await ref.read(huggingfaceTokenProvider.future);
      await _orchestrator.installFromNetwork(
        url,
        token: effectiveToken,
        modelType: resolvedModelType,
        fileType: resolvedFileType,
        cancelToken: cancelToken,
        onProgress: (int progress) {
          if (!_isInstallEpochCurrent(epoch)) {
            return;
          }
          state = state.withInstallProgress(progress);
        },
      );
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
      _invalidateRegistry();
    } on Object catch (e) {
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      if (CancelToken.isCancel(e)) {
        _syncUiToEngine();
        return;
      }
      final ModelInstallDomainError mapped =
          mapModelInstallException(e, downloadUrl: url);
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: mapped.message,
        isGated403: mapped.isGated403,
        gatedModelPageUrl: mapped.gatedModelPageUrl,
        lastFailedDownloadUrl: url,
      );
    } finally {
      _clearInstallTokenIfSame(cancelToken);
    }
  }

  Future<void> installPresetById(
    String presetId, {
    String? token,
  }) async {
    final PredefinedInferenceModel? model = presetInferenceModelById(presetId);
    if (model == null) {
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: 'Unknown preset: $presetId',
      );
      return;
    }
    final int epoch = _beginTrackedInstall(
      ModelInstallActivityKind.downloadNetwork,
    );
    final CancelToken? cancelToken = _installCancelToken;
    try {
      final String? trimmed = token?.trim();
      final String? effectiveToken = (trimmed != null && trimmed.isNotEmpty)
          ? trimmed
          : await ref.read(huggingfaceTokenProvider.future);
      await _orchestrator.installPreset(
        model,
        token: effectiveToken,
        cancelToken: cancelToken,
        onProgress: (int progress) {
          if (!_isInstallEpochCurrent(epoch)) {
            return;
          }
          state = state.withInstallProgress(progress);
        },
      );
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
      _invalidateRegistry();
    } on Object catch (e) {
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      if (CancelToken.isCancel(e)) {
        _syncUiToEngine();
        return;
      }
      final ModelInstallDomainError mapped =
          mapModelInstallException(e, downloadUrl: model.url);
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: mapped.message,
        isGated403: mapped.isGated403,
        gatedModelPageUrl: mapped.gatedModelPageUrl,
        lastFailedDownloadUrl: model.url,
      );
    } finally {
      _clearInstallTokenIfSame(cancelToken);
    }
  }

  Future<void> switchToRegistryEntry(String entryId) async {
    final int epoch = _beginTrackedInstall(
      ModelInstallActivityKind.activateExisting,
    );
    final CancelToken? cancelToken = _installCancelToken;
    try {
      final ModelInstallDomainError? err = await _orchestrator.activateEntry(
        entryId,
        cancelToken: cancelToken,
        onProgress: (int progress) {
          if (!_isInstallEpochCurrent(epoch)) {
            return;
          }
          state = state.withInstallProgress(progress);
        },
      );
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      if (err != null) {
        state = LocalGemmaModelUi(
          phase: LocalGemmaPhase.error,
          errorMessage: err.message,
          isGated403: err.isGated403,
          gatedModelPageUrl: err.gatedModelPageUrl,
        );
        return;
      }
      state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
      _invalidateRegistry();
    } on Object catch (e) {
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      if (CancelToken.isCancel(e)) {
        _syncUiToEngine();
        return;
      }
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: e.toString(),
      );
    } finally {
      _clearInstallTokenIfSame(cancelToken);
    }
  }

  Future<ModelExportResult> exportRegistryEntryToUserLocation(
    String entryId,
  ) async {
    if (kIsWeb) {
      return ModelExportResult.unsupported();
    }
    final String? path =
        await _orchestrator.resolveExportableModelFilePath(entryId);
    if (path == null) {
      return ModelExportResult.failure('Model file not found.');
    }
    return exportModelFileToUserChosenLocation(absoluteSourcePath: path);
  }

  Future<void> removeRegistryEntry(String entryId) async {
    try {
      final ModelInstallDomainError? err =
          await _orchestrator.removeEntry(entryId);
      if (err != null) {
        state = LocalGemmaModelUi(
          phase: LocalGemmaPhase.error,
          errorMessage: err.message,
        );
        return;
      }
      refreshFromEngine();
      _invalidateRegistry();
    } on Object catch (e) {
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: e.toString(),
      );
    }
  }
}
