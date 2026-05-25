// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'dart:convert';

import 'package:disastron/features/tool_layout/domain/app_tool.dart';
import 'package:disastron/features/tool_layout/domain/app_tool_catalog.dart';
import 'package:disastron/features/tool_layout/domain/tool_placement_defaults.dart';

enum ToolPlacementValidationCode {
  ok,
  mustKeepOneSurface,
}

class ToolPlacementValidation {
  const ToolPlacementValidation({
    required this.code,
    this.messageKey,
  });

  final ToolPlacementValidationCode code;
  final String? messageKey;

  bool get isOk => code == ToolPlacementValidationCode.ok;
}

/// Merges persisted JSON with defaults (unknown keys ignored).
Map<String, ToolPlacementFlags> mergeToolPlacements(
  Map<String, ToolPlacementFlags> defaults,
  String? rawJson,
) {
  final Map<String, ToolPlacementFlags> merged =
      Map<String, ToolPlacementFlags>.from(defaults);

  if (rawJson == null || rawJson.isEmpty) {
    return merged;
  }

  final Object? decoded = jsonDecode(rawJson);
  if (decoded is! Map<String, dynamic>) {
    return merged;
  }

  for (final String id in AppToolCatalog.allConfigurableIds) {
    final Object? entry = decoded[id];
    if (entry is Map<String, dynamic>) {
      merged[id] = ToolPlacementFlags.fromJson(entry);
    }
  }
  return merged;
}

String encodeToolPlacements(Map<String, ToolPlacementFlags> placements) {
  final Map<String, dynamic> out = <String, dynamic>{};
  for (final MapEntry<String, ToolPlacementFlags> e in placements.entries) {
    if (!AppToolCatalog.allConfigurableIds.contains(e.key)) {
      continue;
    }
    out[e.key] = e.value.toJson();
  }
  return jsonEncode(out);
}

ToolPlacementValidation validatePlacementChange({
  required Map<String, ToolPlacementFlags> current,
  required String toolId,
  required AppToolSurface surface,
  required bool newValue,
}) {
  if (!AppToolCatalog.mustStayReachableIds.contains(toolId)) {
    return const ToolPlacementValidation(
      code: ToolPlacementValidationCode.ok,
    );
  }

  final ToolPlacementFlags existing = current[toolId] ??
      const ToolPlacementFlags(dashboard: false, drawer: false);

  final ToolPlacementFlags after = switch (surface) {
    AppToolSurface.dashboard => existing.copyWith(dashboard: newValue),
    AppToolSurface.drawer => existing.copyWith(drawer: newValue),
  };

  if (after.dashboard || after.drawer) {
    return const ToolPlacementValidation(
      code: ToolPlacementValidationCode.ok,
    );
  }

  return const ToolPlacementValidation(
    code: ToolPlacementValidationCode.mustKeepOneSurface,
    messageKey: 'tool_layout_validation_must_keep_one',
  );
}

Map<String, ToolPlacementFlags> loadPlacementsFromPrefs(String? raw) {
  return mergeToolPlacements(buildToolPlacementDefaults(), raw);
}
