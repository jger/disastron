import 'dart:io' show File;

import 'package:disastron/features/inference/data/lora_registry_store.dart';
import 'package:disastron/features/inference/presentation/model_install_orchestrator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lora_provider.g.dart';

/// Reactive snapshot of the full LoRA registry.
/// Invalidated whenever an install / remove / setActive operation completes.
@Riverpod(keepAlive: true)
Future<LoraRegistrySnapshot> loraRegistrySnapshot(Ref ref) async {
  final LoraRegistryStore store = LoraRegistryStore();
  return store.readSnapshot();
}

/// Resolves the absolute on-disk path of the active LoRA file for [modelEntryId],
/// or null if no LoRA is active or the file is missing.
///
/// Used by GemmaLocalService to pass `loraPath` to `model.createChat()`.
@Riverpod(keepAlive: true)
Future<String?> activeLoraPath(Ref ref, String modelEntryId) async {
  final LoraRegistrySnapshot snap =
      await ref.watch(loraRegistrySnapshotProvider.future);
  final InstalledLoraEntry? active = snap.activeLoraForModel(modelEntryId);
  if (active == null) return null;
  return _resolveLoraFilePath(active);
}

/// Derives the on-disk path for a LoRA entry. Imported files use their stored
/// absolute path; downloaded files live in [getApplicationDocumentsDirectory].
Future<String?> resolveLoraFilePathFor(InstalledLoraEntry entry) async {
  final String path = await _resolveLoraFilePath(entry);
  if (!File(path).existsSync()) return null;
  return path;
}

Future<String> _resolveLoraFilePath(InstalledLoraEntry entry) async {
  if (entry.importedFromPicker) return entry.sourceUrlOrPath;
  final String dir = (await getApplicationDocumentsDirectory()).path;
  return p.join(dir, basenameFromStored(entry.sourceUrlOrPath));
}
