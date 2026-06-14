import 'dart:io' show File;

/// Coordinates inference installs (network, file, preset): maps native errors to domain errors for UI.
import 'package:disastron/features/inference/data/lora_registry_store.dart';
import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:disastron/features/inference/domain/inference_model_descriptor.dart';
import 'package:disastron/features/inference/domain/model_install_domain_error.dart';
import 'package:disastron/features/inference/domain/predefined_models.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_gemma/core/di/service_registry.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String basenameFromStored(String urlOrPath) {
  final Uri uri =
      urlOrPath.contains('://') ? Uri.parse(urlOrPath) : Uri.file(urlOrPath);
  if (uri.pathSegments.isEmpty) {
    return urlOrPath;
  }
  return uri.pathSegments.last;
}

class ColdStartRestoreResult {
  const ColdStartRestoreResult._({
    required this.attempted,
    this.error,
  });

  const ColdStartRestoreResult.skipped() : this._(attempted: false);

  const ColdStartRestoreResult.success() : this._(attempted: true);

  ColdStartRestoreResult.failure(ModelInstallDomainError err)
      : this._(attempted: true, error: err);

  final bool attempted;
  final ModelInstallDomainError? error;
}

/// Install / activate / remove inference models (delegates IO to [FlutterGemma]).
class ModelInstallOrchestrator {
  ModelInstallOrchestrator({required ModelRegistryStore registry})
      : _registry = registry;

  final ModelRegistryStore _registry;
  final LoraRegistryStore _loraRegistry = LoraRegistryStore();

  String _entryIdForPreset(String presetId) => 'preset:$presetId';

  String _entryIdForUrl(String url) => 'url:${url.hashCode}';

  String _entryIdForFilePath(String path) => 'file:${path.hashCode}';

  Future<String> _resolveLocalFilePath(InstalledModelEntry entry) async {
    if (entry.importedFromPicker) {
      return entry.sourceUrlOrPath;
    }
    final String dir = (await getApplicationDocumentsDirectory()).path;
    return p.join(dir, basenameFromStored(entry.sourceUrlOrPath));
  }

  bool _isNetworkSource(String source) => source.contains('://');

  Future<void> _installInstalledEntry(
    InstalledModelEntry entry, {
    required void Function(int progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    var builder = FlutterGemma.installModel(
      modelType: entry.modelType,
      fileType: entry.fileType,
    ).withProgress(onProgress);
    if (cancelToken != null) {
      builder = builder.withCancelToken(cancelToken);
    }

    if (kIsWeb) {
      if (entry.importedFromPicker &&
          !_isNetworkSource(entry.sourceUrlOrPath)) {
        await builder.fromFile(entry.sourceUrlOrPath).install();
        return;
      }
      if (_isNetworkSource(entry.sourceUrlOrPath)) {
        await builder.fromNetwork(entry.sourceUrlOrPath).install();
        return;
      }
      throw StateError(
        'Unsupported web model source: ${entry.sourceUrlOrPath}',
      );
    }

    final String localPath = await _resolveLocalFilePath(entry);
    await builder.fromFile(localPath).install();
  }

  /// On-disk path for an installed entry, or null if missing / web.
  Future<String?> resolveExportableModelFilePath(String entryId) async {
    if (kIsWeb) {
      return null;
    }
    await _registry.migrateFromLegacyIfNeeded();
    final ModelRegistrySnapshot snap = await _registry.readSnapshot();
    final InstalledModelEntry? entry = snap.entryById(entryId);
    if (entry == null) {
      return null;
    }
    final String path = await _resolveLocalFilePath(entry);
    if (!File(path).existsSync()) {
      return null;
    }
    return path;
  }

  Future<void> installFromFile(
    String path, {
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final InferenceModelDescriptor d =
        InferenceModelDescriptor.fromUrlOrPath(path);
    final String id = _entryIdForFilePath(path);
    final String title = d.displayTitle ?? basenameFromStored(path);
    var builder = FlutterGemma.installModel(
      modelType: d.modelType,
      fileType: d.fileType,
    ).fromFile(path);
    if (onProgress != null) {
      builder = builder.withProgress(onProgress);
    }
    if (cancelToken != null) {
      builder = builder.withCancelToken(cancelToken);
    }
    await builder.install();
    await _upsertAfterSuccess(
      InstalledModelEntry(
        id: id,
        sourceUrlOrPath: path,
        modelType: d.modelType,
        fileType: d.fileType,
        displayTitle: title,
        presetId: d.presetId,
        importedFromPicker: true,
      ),
    );
  }

  Future<void> installFromNetwork(
    String url, {
    String? token,
    ModelType? modelType,
    ModelFileType? fileType,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final InferenceModelDescriptor inferred =
        InferenceModelDescriptor.fromUrlOrPath(url);
    final ModelType resolvedType = modelType ?? inferred.modelType;
    final ModelFileType resolvedFile = fileType ?? inferred.fileType;
    final String? presetId = inferred.presetId;
    final String id =
        presetId != null ? _entryIdForPreset(presetId) : _entryIdForUrl(url);
    final String title = inferred.displayTitle ?? basenameFromStored(url);

    var netBuilder = FlutterGemma.installModel(
      modelType: resolvedType,
      fileType: resolvedFile,
    ).fromNetwork(url, token: token);
    if (onProgress != null) {
      netBuilder = netBuilder.withProgress(onProgress);
    }
    if (cancelToken != null) {
      netBuilder = netBuilder.withCancelToken(cancelToken);
    }
    await netBuilder.install();

    await _upsertAfterSuccess(
      InstalledModelEntry(
        id: id,
        sourceUrlOrPath: url,
        modelType: resolvedType,
        fileType: resolvedFile,
        displayTitle: title,
        presetId: presetId,
      ),
    );
  }

  Future<void> installPreset(
    PredefinedInferenceModel model, {
    String? token,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await installFromNetwork(
      model.url,
      token: token,
      modelType: model.modelType,
      fileType: model.fileType,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<ColdStartRestoreResult> tryRestoreOnColdStart({
    required void Function(int progress) onProgress,
    void Function()? onRestoreBegins,
  }) async {
    if (FlutterGemma.hasActiveModel()) {
      return const ColdStartRestoreResult.skipped();
    }
    await _registry.migrateFromLegacyIfNeeded();
    final ModelRegistrySnapshot snap = await _registry.readSnapshot();
    final String? activeId = snap.activeEntryId;
    if (activeId == null) {
      return const ColdStartRestoreResult.skipped();
    }
    final InstalledModelEntry? entry = snap.entryById(activeId);
    if (entry == null) {
      return const ColdStartRestoreResult.skipped();
    }
    final String filename = basenameFromStored(entry.sourceUrlOrPath);
    final bool installed = await FlutterGemma.isModelInstalled(filename);
    if (!installed) {
      return const ColdStartRestoreResult.skipped();
    }
    onRestoreBegins?.call();
    try {
      await _installInstalledEntry(entry, onProgress: onProgress);
      return const ColdStartRestoreResult.success();
    } on Object catch (e) {
      return ColdStartRestoreResult.failure(mapModelInstallException(e));
    }
  }

  Future<ModelInstallDomainError?> activateEntry(
    String entryId, {
    required void Function(int progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    await _registry.migrateFromLegacyIfNeeded();
    final ModelRegistrySnapshot snap = await _registry.readSnapshot();
    final InstalledModelEntry? entry = snap.entryById(entryId);
    if (entry == null) {
      return const ModelInstallDomainError(
        kind: ModelInstallDomainErrorKind.unknown,
        message: 'Model entry not found',
      );
    }
    final String filename = basenameFromStored(entry.sourceUrlOrPath);
    final bool installed = await FlutterGemma.isModelInstalled(filename);
    if (!installed) {
      return const ModelInstallDomainError(
        kind: ModelInstallDomainErrorKind.unknown,
        message: 'Model files missing; download or import again.',
      );
    }
    try {
      await _installInstalledEntry(
        entry,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      final ModelRegistrySnapshot next = ModelRegistrySnapshot(
        entries: snap.entries,
        activeEntryId: entryId,
      );
      await _registry.writeSnapshot(next);
      return null;
    } on Object catch (e) {
      if (CancelToken.isCancel(e)) {
        rethrow;
      }
      return mapModelInstallException(e);
    }
  }

  Future<ModelInstallDomainError?> removeEntry(String entryId) async {
    await _registry.migrateFromLegacyIfNeeded();
    ModelRegistrySnapshot snap = await _registry.readSnapshot();
    final InstalledModelEntry? entry = snap.entryById(entryId);
    if (entry == null) {
      return const ModelInstallDomainError(
        kind: ModelInstallDomainErrorKind.unknown,
        message: 'Model entry not found',
      );
    }
    final String modelId = basenameFromStored(entry.sourceUrlOrPath);
    try {
      await FlutterGemma.uninstallModel(modelId);
    } on Object catch (e) {
      return mapModelInstallException(e);
    }
    final List<InstalledModelEntry> nextEntries =
        snap.entries.where((InstalledModelEntry e) => e.id != entryId).toList();
    String? nextActive = snap.activeEntryId;
    if (nextActive == entryId) {
      nextActive = null;
    }
    snap =
        ModelRegistrySnapshot(entries: nextEntries, activeEntryId: nextActive);
    await _registry.writeSnapshot(snap);
    return null;
  }

  Future<void> _upsertAfterSuccess(InstalledModelEntry entry) async {
    await _registry.migrateFromLegacyIfNeeded();
    ModelRegistrySnapshot snap = await _registry.readSnapshot();
    final List<InstalledModelEntry> list = <InstalledModelEntry>[
      ...snap.entries.where((InstalledModelEntry e) => e.id != entry.id),
      entry,
    ];
    snap = ModelRegistrySnapshot(
      entries: list,
      activeEntryId: entry.id,
    );
    await _registry.writeSnapshot(snap);
  }

  /// Sync registry active entry when the plugin already has a model (e.g. after external init).
  Future<void> reconcileActiveWithPluginIfPossible() async {
    if (!FlutterGemma.hasActiveModel()) {
      return;
    }
    await _registry.migrateFromLegacyIfNeeded();
    final ModelRegistrySnapshot snap = await _registry.readSnapshot();
    final InferenceModelSpec? spec = FlutterGemmaPlugin
        .instance.modelManager.activeInferenceModel as InferenceModelSpec?;
    if (spec == null) {
      return;
    }
    final String? fname =
        spec.files.isNotEmpty ? spec.files.first.filename : null;
    if (fname == null) {
      return;
    }
    InstalledModelEntry? match;
    for (final InstalledModelEntry e in snap.entries) {
      if (basenameFromStored(e.sourceUrlOrPath) == fname) {
        match = e;
        break;
      }
    }
    if (match != null && snap.activeEntryId != match.id) {
      await _registry.writeSnapshot(
        ModelRegistrySnapshot(
          entries: snap.entries,
          activeEntryId: match.id,
        ),
      );
    }
  }

  // --- LoRA Operations ---

  Future<void> installLoraFromNetwork(
    String url,
    String modelEntryId, {
    String? token,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final String filename = basenameFromStored(url);
    final String targetPath = p.join(
      (await getApplicationDocumentsDirectory()).path,
      filename,
    );

    final String loraEntryId = 'lora:${url.hashCode}';

    if (onProgress != null) {
      await for (final progress
          in ServiceRegistry.instance.downloadService.downloadWithProgress(
        url,
        targetPath,
        token: token,
        cancelToken: cancelToken,
      )) {
        onProgress(progress);
      }
    } else {
      await ServiceRegistry.instance.downloadService.download(
        url,
        targetPath,
        token: token,
        cancelToken: cancelToken,
      );
    }

    final LoraRegistrySnapshot snap = await _loraRegistry.readSnapshot();
    final InstalledLoraEntry entry = InstalledLoraEntry(
      id: loraEntryId,
      modelEntryId: modelEntryId,
      sourceUrlOrPath: url,
      displayLabel: filename,
    );
    final List<InstalledLoraEntry> nextEntries = <InstalledLoraEntry>[
      ...snap.entries.where((InstalledLoraEntry e) => e.id != loraEntryId),
      entry,
    ];
    final Map<String, String> nextActive =
        Map<String, String>.from(snap.activeLoraIdPerModel);
    nextActive[modelEntryId] = loraEntryId;

    await _loraRegistry.writeSnapshot(
      LoraRegistrySnapshot(
        entries: nextEntries,
        activeLoraIdPerModel: nextActive,
      ),
    );
  }

  Future<void> installLoraFromFile(String path, String modelEntryId) async {
    final String loraEntryId = 'lora:${path.hashCode}';
    final String label = basenameFromStored(path);
    final LoraRegistrySnapshot snap = await _loraRegistry.readSnapshot();
    final InstalledLoraEntry entry = InstalledLoraEntry(
      id: loraEntryId,
      modelEntryId: modelEntryId,
      sourceUrlOrPath: path,
      displayLabel: label,
      importedFromPicker: true,
    );
    final List<InstalledLoraEntry> nextEntries = <InstalledLoraEntry>[
      ...snap.entries.where((InstalledLoraEntry e) => e.id != loraEntryId),
      entry,
    ];
    final Map<String, String> nextActive =
        Map<String, String>.from(snap.activeLoraIdPerModel);
    nextActive[modelEntryId] = loraEntryId;

    await _loraRegistry.writeSnapshot(
      LoraRegistrySnapshot(
        entries: nextEntries,
        activeLoraIdPerModel: nextActive,
      ),
    );
  }

  Future<void> removeLoraEntry(String loraEntryId) async {
    final LoraRegistrySnapshot snap = await _loraRegistry.readSnapshot();
    final InstalledLoraEntry? entry = snap.entryById(loraEntryId);
    if (entry == null) return;

    if (!entry.importedFromPicker) {
      final String filename = basenameFromStored(entry.sourceUrlOrPath);
      final String localPath = p.join(
        (await getApplicationDocumentsDirectory()).path,
        filename,
      );
      final File file = File(localPath);
      if (file.existsSync()) {
        await file.delete();
      }
    }

    final List<InstalledLoraEntry> nextEntries = snap.entries
        .where((InstalledLoraEntry e) => e.id != loraEntryId)
        .toList();
    final Map<String, String> nextActive =
        Map<String, String>.from(snap.activeLoraIdPerModel)
          ..removeWhere((String k, String v) => v == loraEntryId);

    await _loraRegistry.writeSnapshot(
      LoraRegistrySnapshot(
        entries: nextEntries,
        activeLoraIdPerModel: nextActive,
      ),
    );
  }

  Future<void> updateLoraLabel(String loraEntryId, String nextLabel) async {
    final LoraRegistrySnapshot snap = await _loraRegistry.readSnapshot();
    final List<InstalledLoraEntry> nextEntries =
        snap.entries.map((InstalledLoraEntry e) {
      if (e.id == loraEntryId) {
        return InstalledLoraEntry(
          id: e.id,
          modelEntryId: e.modelEntryId,
          sourceUrlOrPath: e.sourceUrlOrPath,
          displayLabel: nextLabel,
          importedFromPicker: e.importedFromPicker,
        );
      }
      return e;
    }).toList();
    await _loraRegistry.writeSnapshot(
      LoraRegistrySnapshot(
        entries: nextEntries,
        activeLoraIdPerModel: snap.activeLoraIdPerModel,
      ),
    );
  }

  Future<void> setActiveLora(String? loraEntryId, String modelEntryId) async {
    final LoraRegistrySnapshot snap = await _loraRegistry.readSnapshot();
    final Map<String, String> nextActive =
        Map<String, String>.from(snap.activeLoraIdPerModel);
    if (loraEntryId == null) {
      nextActive.remove(modelEntryId);
    } else {
      nextActive[modelEntryId] = loraEntryId;
    }
    await _loraRegistry.writeSnapshot(
      LoraRegistrySnapshot(
        entries: snap.entries,
        activeLoraIdPerModel: nextActive,
      ),
    );
  }
}
