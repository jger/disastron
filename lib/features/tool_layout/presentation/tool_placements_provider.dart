// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:disastron/features/tool_layout/domain/app_tool.dart';
import 'package:disastron/features/tool_layout/domain/app_tool_catalog.dart';
import 'package:disastron/features/tool_layout/domain/tool_placement_defaults.dart';
import 'package:disastron/features/tool_layout/domain/tool_placement_logic.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'tool_placements_provider.g.dart';

@Riverpod(keepAlive: true)
class ToolPlacements extends _$ToolPlacements {
  @override
  Future<Map<String, ToolPlacementFlags>> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(PrefsKeys.toolPlacements);
    return loadPlacementsFromPrefs(raw);
  }

  Map<String, ToolPlacementFlags> _current() {
    return Map<String, ToolPlacementFlags>.from(
      state.value ?? buildToolPlacementDefaults(),
    );
  }

  Future<ToolPlacementValidation> setPlacement({
    required String toolId,
    required AppToolSurface surface,
    required bool value,
  }) async {
    if (!AppToolCatalog.placementConfigurableIds.contains(toolId)) {
      return const ToolPlacementValidation(
        code: ToolPlacementValidationCode.ok,
      );
    }
    final Map<String, ToolPlacementFlags> current = _current();
    final ToolPlacementValidation validation = validatePlacementChange(
      current: current,
      toolId: toolId,
      surface: surface,
      newValue: value,
    );
    if (!validation.isOk) {
      return validation;
    }

    final ToolPlacementFlags existing = current[toolId] ??
        const ToolPlacementFlags(dashboard: false, drawer: false);
    final ToolPlacementFlags updated = switch (surface) {
      AppToolSurface.dashboard => existing.copyWith(dashboard: value),
      AppToolSurface.drawer => existing.copyWith(drawer: value),
    };

    final Map<String, ToolPlacementFlags> next =
        Map<String, ToolPlacementFlags>.from(current)..[toolId] = updated;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsKeys.toolPlacements,
      encodeToolPlacements(next),
    );
    state = AsyncValue<Map<String, ToolPlacementFlags>>.data(next);
    return validation;
  }

  Future<void> resetToDefaults() async {
    final Map<String, ToolPlacementFlags> defaults =
        buildToolPlacementDefaults();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.toolPlacements);
    state = AsyncValue<Map<String, ToolPlacementFlags>>.data(defaults);
  }
}
