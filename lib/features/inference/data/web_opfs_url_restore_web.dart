// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:disastron/features/inference/domain/inference_path_utils.dart';
import 'package:flutter_edge_ai/core/di/service_registry.dart';
import 'package:flutter_edge_ai/core/infrastructure/web_file_system_service.dart';
import 'package:flutter_edge_ai/core/infrastructure/web_opfs_service.dart';

void registerWebOpfsUrl(String filename) {
  final fs = ServiceRegistry.instance.fileSystemService;
  if (fs is WebFileSystemService) {
    fs.registerUrl(filename, 'opfs://$filename');
  }
}

/// Re-register in-memory `opfs://` URLs after a PWA reload (OPFS bytes persist).
Future<void> restoreWebOpfsModelUrlsFromRegistry(
  ModelRegistryStore store,
) async {
  await store.migrateFromLegacyIfNeeded();
  final ModelRegistrySnapshot snap = await store.readSnapshot();
  final String? activeId = snap.activeEntryId;
  if (activeId == null) {
    return;
  }
  final InstalledModelEntry? entry = snap.entryById(activeId);
  if (entry == null) {
    return;
  }
  final String filename = basenameFromStored(entry.sourceUrlOrPath);
  final WebOPFSService opfs = WebOPFSService.fromWindow();
  if (!await opfs.isModelCached(filename)) {
    return;
  }
  registerWebOpfsUrl(filename);
}

Future<bool> isWebOpfsModelCached(String filename) async {
  final WebOPFSService opfs = WebOPFSService.fromWindow();
  return opfs.isModelCached(filename);
}
