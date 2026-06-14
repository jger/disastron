import 'dart:async';
import 'dart:developer' as developer;

import 'package:disastron/features/inference/data/huggingface_token_store.dart';
import 'package:disastron/features/inference/data/model_download_resume_service.dart';
import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:disastron/features/inference/data/pending_model_download_store.dart';
import 'package:disastron/features/inference/domain/inference_model_descriptor.dart';
import 'package:disastron/features/inference/domain/model_install_activity_kind.dart';
import 'package:disastron/features/inference/domain/model_install_domain_error.dart';
import 'package:disastron/features/inference/domain/model_operation_state.dart';
import 'package:disastron/features/inference/domain/predefined_models.dart'
    show
        PredefinedInferenceModel,
        modelFileTypeForUrl,
        presetInferenceModelById;
import 'package:disastron/features/inference/presentation/huggingface_token_provider.dart';
import 'package:disastron/features/inference/presentation/lora_provider.dart';
import 'package:disastron/features/inference/presentation/model_file_export.dart';
import 'package:disastron/features/inference/presentation/model_install_orchestrator.dart';
import 'package:disastron/features/inference/presentation/model_registry_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_gemma_model_provider.g.dart';

/// Riverpod surface for install lifecycle: delegates heavy work to the install orchestrator
/// and syncs FlutterGemma when install completes. Gated HF models set `isGated403`.
enum LocalGemmaPhase {
  notInstalled,
  installing,
  ready,
  error,

  /// Network download stopped with partial bytes on disk (user can resume).
  downloadInterrupted,
}

class LocalGemmaModelUi {
  const LocalGemmaModelUi({
    required this.phase,
    this.progress = 0,
    this.activity = ModelInstallActivityKind.unknown,
    this.errorMessage,
    this.isGated403 = false,
    this.gatedModelPageUrl,
    this.lastFailedDownloadUrl,
    this.pendingDownloadUrl,
    this.pendingProgress,
    this.pendingPresetId,
  });

  final LocalGemmaPhase phase;
  final int progress;
  final ModelInstallActivityKind activity;
  final String? errorMessage;
  final bool isGated403;
  final String? gatedModelPageUrl;
  final String? lastFailedDownloadUrl;
  final String? pendingDownloadUrl;
  final int? pendingProgress;
  final String? pendingPresetId;

  bool get isReady => phase == LocalGemmaPhase.ready;

  /// Progress update while keeping [activity] and clearing error-only fields.
  LocalGemmaModelUi withInstallProgress(int newProgress) {
    return LocalGemmaModelUi(
      phase: LocalGemmaPhase.installing,
      progress: newProgress,
      activity: activity,
      pendingDownloadUrl: pendingDownloadUrl,
      pendingPresetId: pendingPresetId,
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
  final PendingModelDownloadStore _pendingStore = PendingModelDownloadStore();
  final ModelDownloadResumeService _resumeService =
      const ModelDownloadResumeService();
  bool _restoreInFlight = false;
  bool _pendingRefreshInFlight = false;

  /// Bumps when a new install/preflight starts or user cancels, so stale
  /// plugin callbacks don't overwrite UI.
  int _installEpoch = 0;

  CancelToken? _installCancelToken;

  // Fires when no download progress arrives for [_stallTimeout], which means
  // the background WorkManager job is stuck (e.g. after a WiFi reconnect that
  // killed and refused to reschedule the job). Cancelling the token flows into
  // the normal interrupted-state recovery path.
  static const Duration _stallTimeout = Duration(seconds: 90);
  Timer? _progressStallTimer;

  /// Handles network download progress. Ignores regressive ticks (SmartDownloader
  /// clamps failure sentinel -100% to 0%) so the stall timer is not reset while
  /// resume is pending on a dead WorkManager job.
  void _onNetworkInstallProgress(int epoch, int progress) {
    void apply() {
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      final int current = state.progress;
      if (progress < current) {
        developer.log(
          'Ignoring regressive progress $progress% (current $current%) — '
          'likely failure/resume sentinel; stall timer unchanged.',
          name: 'LocalGemmaModel',
        );
        return;
      }
      if (!kIsWeb) {
        _resetStallTimer(epoch);
      }
      unawaited(_updatePendingProgress(progress));
      state = state.withInstallProgress(progress);
    }

    // JS interop progress callbacks may not schedule a frame on web.
    if (kIsWeb) {
      scheduleMicrotask(apply);
      return;
    }
    apply();
  }

  /// Resets the stall-detection countdown. Call at install start and on every
  /// valid progress tick.
  void _resetStallTimer(int epoch) {
    _progressStallTimer?.cancel();
    _progressStallTimer = Timer(_stallTimeout, () {
      if (!_isInstallEpochCurrent(epoch)) return;
      if (state.phase != LocalGemmaPhase.installing) return;
      developer.log(
        'Download stalled (no progress for ${_stallTimeout.inSeconds}s) — '
        'auto-cancelling to trigger interrupted-state recovery.',
        name: 'LocalGemmaModel',
      );
      _installCancelToken?.cancel('Download stalled');
    });
  }

  void _cancelStallTimer() {
    _progressStallTimer?.cancel();
    _progressStallTimer = null;
  }

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
    _cancelStallTimer();
    _installCancelToken?.cancel(reason);
    _installCancelToken = null;
    _installEpoch++;
  }

  Future<void> _savePendingNetworkDownload({
    required String url,
    required ModelType modelType,
    required ModelFileType fileType,
    String? presetId,
    int progress = 0,
  }) async {
    if (kIsWeb) {
      return;
    }
    await _pendingStore.save(
      PendingModelDownload(
        url: url,
        filename: basenameFromStored(url),
        presetId: presetId,
        modelType: modelType,
        fileType: fileType,
        lastProgress: progress,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _updatePendingProgress(int progress) async {
    if (kIsWeb) {
      return;
    }
    await _pendingStore.updateProgress(progress);
  }

  Future<void> _clearPendingDownload() async {
    await _pendingStore.clear();
  }

  Future<void> _applyInterruptedState(PendingModelDownload pending) async {
    final ResumableDownloadSnapshot snap =
        await _resumeService.detectResumable(pending);
    if (!snap.resumable) {
      await _clearPendingDownload();
      _syncUiToEngine();
      return;
    }
    state = LocalGemmaModelUi(
      phase: LocalGemmaPhase.downloadInterrupted,
      pendingDownloadUrl: pending.url,
      pendingProgress: pending.lastProgress,
      pendingPresetId: pending.presetId,
      activity: ModelInstallActivityKind.downloadNetwork,
    );
    developer.log(
      'downloadInterrupted url=${pending.url} progress=${pending.lastProgress}',
      name: 'LocalGemmaModel',
    );
  }

  Future<void> _maybeTransitionToInterrupted(String url) async {
    if (kIsWeb) {
      _syncUiToEngine();
      return;
    }
    final PendingModelDownload? pending = await _pendingStore.read();
    if (pending == null || pending.url != url) {
      _syncUiToEngine();
      return;
    }
    await _applyInterruptedState(pending);
  }

  /// Re-reads prefs and shows [LocalGemmaPhase.downloadInterrupted] when resumable.
  Future<void> refreshPendingDownload() async {
    if (kIsWeb) {
      return;
    }
    if (state.phase == LocalGemmaPhase.installing ||
        state.phase == LocalGemmaPhase.ready) {
      return;
    }
    if (_pendingRefreshInFlight) {
      return;
    }
    _pendingRefreshInFlight = true;
    try {
      final PendingModelDownload? pending = await _pendingStore.read();
      if (pending == null) {
        if (state.phase == LocalGemmaPhase.downloadInterrupted) {
          _syncUiToEngine();
        }
        return;
      }
      final ResumableDownloadSnapshot snap =
          await _resumeService.detectResumable(pending);
      if (!snap.resumable) {
        await _clearPendingDownload();
        if (state.phase == LocalGemmaPhase.downloadInterrupted) {
          _syncUiToEngine();
        }
        return;
      }
      await _applyInterruptedState(pending);
    } finally {
      _pendingRefreshInFlight = false;
    }
  }

  /// Continues a previously interrupted network download (preset or custom URL).
  Future<void> resumePendingNetworkInstall() async {
    final PendingModelDownload? pending = await _pendingStore.read();
    if (pending == null) {
      final String? fallbackUrl = state.lastFailedDownloadUrl;
      if (fallbackUrl != null) {
        await installFromNetwork(fallbackUrl);
      }
      return;
    }
    if (pending.presetId != null) {
      await installPresetById(pending.presetId!);
      return;
    }
    await installFromNetwork(
      pending.url,
      modelType: pending.modelType,
      fileType: pending.fileType,
    );
  }

  /// Deletes partial bytes and clears interrupted state.
  Future<void> discardPendingDownload() async {
    final PendingModelDownload? pending = await _pendingStore.read();
    if (pending != null && !kIsWeb) {
      await _resumeService.discardPending(pending);
    }
    await _clearPendingDownload();
    _syncUiToEngine();
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

  /// User-facing cancel: stops active install; keeps partial file when resumable.
  void requestInstallCancel() {
    if (state.phase != LocalGemmaPhase.installing) {
      return;
    }
    final bool wasNetworkDownload =
        state.activity == ModelInstallActivityKind.downloadNetwork;
    _bumpEpochAndCancelToken('User cancelled');
    if (wasNetworkDownload) {
      unawaited(_handleNetworkInstallCancelled());
      return;
    }
    _syncUiToEngine();
  }

  Future<void> _handleNetworkInstallCancelled() async {
    final PendingModelDownload? pending = await _pendingStore.read();
    if (pending != null) {
      await _applyInterruptedState(pending);
      return;
    }
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
    // On web, flutter_gemma restores _activeInferenceModel from SharedPreferences
    // on initialize(), so hasActiveModel() may be true. But the OPFS blob URL is
    // lost on every page reload and must be re-registered before getActiveModel()
    // is called. Always run _tryRestoreModel() on web to ensure the URL is
    // re-registered, and return notInstalled so chat waits for the restore.
    if (!active || kIsWeb) {
      unawaited(
        _tryRestoreModel().then((_) => refreshPendingDownload()),
      );
      // On web, even when active=true the OPFS URL needs re-registration first.
      // Return notInstalled so chat waits for restore to set state to ready.
      return const LocalGemmaModelUi(phase: LocalGemmaPhase.notInstalled);
    }
    unawaited(_orchestrator.reconcileActiveWithPluginIfPossible());
    return const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
  }

  void refreshFromEngine() {
    if (state.phase == LocalGemmaPhase.installing) {
      developer.log(
        'refreshFromEngine skipped — installing',
        name: 'disastron.chat_init',
      );
      return;
    }
    final bool active = FlutterGemma.hasActiveModel();
    developer.log(
      'refreshFromEngine hasActiveModel=$active phase=${state.phase}',
      name: 'disastron.chat_init',
    );
    state = LocalGemmaModelUi(
      phase: active ? LocalGemmaPhase.ready : LocalGemmaPhase.notInstalled,
    );
    if (FlutterGemma.hasActiveModel()) {
      unawaited(_orchestrator.reconcileActiveWithPluginIfPossible());
      _invalidateRegistry();
    } else {
      unawaited(_tryRestoreModel());
      unawaited(refreshPendingDownload());
    }
  }

  Future<void> _tryRestoreModel() async {
    // On web the active model identity is persisted by flutter_gemma in
    // SharedPreferences and restored during initialize(), so hasActiveModel()
    // can be true even though the OPFS URL is not yet registered. Skip the
    // early return on web so _installInstalledEntry re-registers the URL.
    if (!kIsWeb && FlutterGemma.hasActiveModel()) {
      return;
    }
    if (_restoreInFlight) {
      return;
    }
    _restoreInFlight = true;
    try {
      final ModelRegistryStore store = ModelRegistryStore();
      await store.migrateFromLegacyIfNeeded();
      final ModelRegistrySnapshot snap = await store.readSnapshot();
      final String? activeId = snap.activeEntryId;
      final InstalledModelEntry? entry =
          activeId != null ? snap.entryById(activeId) : null;
      final String? hfToken = await HuggingfaceTokenStore().read();

      final ColdStartRestoreResult result =
          await _orchestrator.tryRestoreOnColdStart(
        huggingFaceToken: hfToken,
        onProgress: (int progress) {
          if (state.activity != ModelInstallActivityKind.restoreSaved) {
            return;
          }
          state = state.withInstallProgress(progress);
        },
        onRestoreBegins: () {
          state = LocalGemmaModelUi(
            phase: LocalGemmaPhase.installing,
            activity: ModelInstallActivityKind.restoreSaved,
            pendingDownloadUrl: entry?.sourceUrlOrPath,
            pendingPresetId: entry?.presetId,
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
    state = state.copyWithPendingUrl(path);
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
    final InferenceModelDescriptor inferred =
        InferenceModelDescriptor.fromUrlOrPath(url);
    final ModelType resolvedModelType = modelType ?? inferred.modelType;
    final ModelFileType resolvedFileType = fileType ?? inferred.fileType;
    final String? presetId = inferred.presetId;

    final int epoch = _beginTrackedInstall(
      ModelInstallActivityKind.downloadNetwork,
    );
    await _savePendingNetworkDownload(
      url: url,
      modelType: resolvedModelType,
      fileType: resolvedFileType,
      presetId: presetId,
    );
    state = state.copyWithPendingUrl(url, presetId: presetId);

    final CancelToken? cancelToken = _installCancelToken;
    try {
      final String? trimmed = token?.trim();
      final String? effectiveToken = (trimmed != null && trimmed.isNotEmpty)
          ? trimmed
          : await ref.read(huggingfaceTokenProvider.future);
      if (!kIsWeb) {
        await _resumeService.cancelStaleTask(url);
        _resetStallTimer(epoch);
      }
      await _orchestrator.installFromNetwork(
        url,
        token: effectiveToken,
        modelType: resolvedModelType,
        fileType: resolvedFileType,
        cancelToken: cancelToken,
        onProgress: (int progress) {
          _onNetworkInstallProgress(epoch, progress);
        },
      );
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      await _clearPendingDownload();
      state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
      _invalidateRegistry();
    } on Object catch (e) {
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      if (CancelToken.isCancel(e)) {
        await _maybeTransitionToInterrupted(url);
        return;
      }
      final ModelInstallDomainError mapped =
          mapModelInstallException(e, downloadUrl: url);
      // Only network errors (timeouts, drops) leave a valid partial file worth
      // resuming. Auth/storage/compatibility/unknown errors will fail again on
      // retry, so skip detectResumable to avoid showing "Resume" for a 403 that
      // would loop indefinitely.
      if (mapped.kind == ModelInstallDomainErrorKind.network && !kIsWeb) {
        final PendingModelDownload? pendingAfterError =
            await _pendingStore.read();
        if (pendingAfterError != null) {
          final ResumableDownloadSnapshot snap =
              await _resumeService.detectResumable(pendingAfterError);
          if (snap.resumable) {
            await _applyInterruptedState(pendingAfterError);
            return;
          }
        }
      }
      await _clearPendingDownload();
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: mapped.message,
        isGated403: mapped.isGated403,
        gatedModelPageUrl: mapped.gatedModelPageUrl,
        lastFailedDownloadUrl: url,
      );
    } finally {
      _cancelStallTimer();
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
    await _savePendingNetworkDownload(
      url: model.url,
      presetId: presetId,
      modelType: model.modelType,
      fileType: model.fileType,
    );
    state = state.copyWithPendingUrl(model.url, presetId: presetId);

    final CancelToken? cancelToken = _installCancelToken;
    try {
      final String? trimmed = token?.trim();
      final String? effectiveToken = (trimmed != null && trimmed.isNotEmpty)
          ? trimmed
          : await ref.read(huggingfaceTokenProvider.future);
      if (!kIsWeb) {
        await _resumeService.cancelStaleTask(model.url);
        _resetStallTimer(epoch);
      }
      await _orchestrator.installPreset(
        model,
        token: effectiveToken,
        cancelToken: cancelToken,
        onProgress: (int progress) {
          _onNetworkInstallProgress(epoch, progress);
        },
      );
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      await _clearPendingDownload();
      state = const LocalGemmaModelUi(phase: LocalGemmaPhase.ready);
      _invalidateRegistry();
    } on Object catch (e) {
      if (!_isInstallEpochCurrent(epoch)) {
        return;
      }
      if (CancelToken.isCancel(e)) {
        await _maybeTransitionToInterrupted(model.url);
        return;
      }
      final ModelInstallDomainError mapped =
          mapModelInstallException(e, downloadUrl: model.url);
      // Only network errors leave a valid partial file. Auth/storage/etc. will
      // fail the same way on retry, so bypass detectResumable entirely.
      if (mapped.kind == ModelInstallDomainErrorKind.network && !kIsWeb) {
        final PendingModelDownload? pending = await _pendingStore.read();
        if (pending != null) {
          final ResumableDownloadSnapshot snap =
              await _resumeService.detectResumable(pending);
          if (snap.resumable) {
            await _applyInterruptedState(pending);
            return;
          }
        }
      }
      await _clearPendingDownload();
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: mapped.message,
        isGated403: mapped.isGated403,
        gatedModelPageUrl: mapped.gatedModelPageUrl,
        lastFailedDownloadUrl: model.url,
      );
    } finally {
      _cancelStallTimer();
      _clearInstallTokenIfSame(cancelToken);
    }
  }

  Future<void> switchToRegistryEntry(String entryId) async {
    final ModelRegistrySnapshot snap =
        await ref.read(modelRegistrySnapshotProvider.future);
    final InstalledModelEntry? entry = snap.entryById(entryId);

    final int epoch = _beginTrackedInstall(
      ModelInstallActivityKind.activateExisting,
    );
    if (entry != null) {
      state = state.copyWithPendingUrl(
        entry.sourceUrlOrPath,
        presetId: entry.presetId,
      );
    }
    final CancelToken? cancelToken = _installCancelToken;
    try {
      final String? hfToken = await HuggingfaceTokenStore().read();
      final ModelInstallDomainError? err = await _orchestrator.activateEntry(
        entryId,
        cancelToken: cancelToken,
        huggingFaceToken: hfToken,
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

  Future<void> installLoraFromNetwork(
    String url,
    String modelEntryId, {
    String? token,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _orchestrator.installLoraFromNetwork(
        url,
        modelEntryId,
        token: token,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      _invalidateLoraRegistry();
    } on Object catch (e) {
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> installLoraFromFile(String path, String modelEntryId) async {
    try {
      await _orchestrator.installLoraFromFile(path, modelEntryId);
      _invalidateLoraRegistry();
    } on Object catch (e) {
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> removeLoraEntry(String loraEntryId) async {
    try {
      await _orchestrator.removeLoraEntry(loraEntryId);
      _invalidateLoraRegistry();
    } on Object catch (e) {
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> updateLoraLabel(String loraEntryId, String nextLabel) async {
    try {
      await _orchestrator.updateLoraLabel(loraEntryId, nextLabel);
      _invalidateLoraRegistry();
    } on Object catch (e) {
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> setActiveLora(String? loraEntryId, String modelEntryId) async {
    try {
      await _orchestrator.setActiveLora(loraEntryId, modelEntryId);
      _invalidateLoraRegistry();
    } on Object catch (e) {
      state = LocalGemmaModelUi(
        phase: LocalGemmaPhase.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  void _invalidateLoraRegistry() {
    ref.invalidate(loraRegistrySnapshotProvider);
  }
}

extension _LocalGemmaModelUiPending on LocalGemmaModelUi {
  LocalGemmaModelUi copyWithPendingUrl(String url, {String? presetId}) {
    return LocalGemmaModelUi(
      phase: phase,
      progress: progress,
      activity: activity,
      pendingDownloadUrl: url,
      pendingPresetId: presetId ?? pendingPresetId,
    );
  }
}
