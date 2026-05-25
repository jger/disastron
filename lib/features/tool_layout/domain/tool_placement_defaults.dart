// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/tool_layout/domain/app_tool.dart';
import 'package:disastron/features/tool_layout/domain/app_tool_catalog.dart';

/// Preset placements matching the original app layout.
Map<String, ToolPlacementFlags> buildToolPlacementDefaults() {
  final Map<String, ToolPlacementFlags> map = <String, ToolPlacementFlags>{};

  for (final String id in AppToolCatalog.quickActionIds) {
    map[id] = const ToolPlacementFlags(
      dashboard: true,
      drawer: false,
    );
  }

  for (final String id in AppToolCatalog.settingsIds) {
    map[id] = const ToolPlacementFlags(
      dashboard: false,
      drawer: true,
    );
  }

  for (final String id in AppToolCatalog.wikiArticleIds) {
    final bool onDashboard = id == 'karpa_cpr' || id == 'trip_planning';
    map[id] = ToolPlacementFlags(
      dashboard: onDashboard,
      drawer: false,
    );
  }

  return map;
}
