// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/emergency/emergency_numbers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'emergency_numbers_pack_provider.g.dart';

/// Bundled ISO-country emergency numbers (offline).
@Riverpod(keepAlive: true)
Future<EmergencyNumbersPack> emergencyNumbersPack(Ref ref) {
  return EmergencyNumbersPack.loadBundled();
}
