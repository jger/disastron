/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// SSOT for loading string assets from [rootBundle].
Future<String> loadBundledAssetString(String assetPath) {
  return rootBundle.loadString(assetPath);
}

/// Decodes a single JSON object from a bundled asset.
Future<T> decodeBundledJsonObject<T>(
  String assetPath,
  T Function(Map<String, dynamic> json) fromMap,
) async {
  final String raw = await loadBundledAssetString(assetPath);
  final Object? decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Expected JSON object at $assetPath');
  }
  return fromMap(decoded);
}
