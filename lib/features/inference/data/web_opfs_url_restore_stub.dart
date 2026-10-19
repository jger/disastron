// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/inference/data/model_registry_store.dart';

/// No-op on mobile/desktop.
Future<void> restoreWebOpfsModelUrlsFromRegistry(
  ModelRegistryStore store,
) async {}

/// Always false off-web.
Future<bool> isWebOpfsModelCached(String filename) async => false;

void registerWebOpfsUrl(String filename) {}
