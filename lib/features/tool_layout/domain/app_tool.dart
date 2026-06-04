// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:flutter/material.dart';

enum AppToolKind {
  quickAction,
  settings,
  wikiArticle,
}

enum AppToolSurface {
  dashboard,
  drawer,
}

/// Per-tool visibility on dashboard and drawer.
class ToolPlacementFlags {
  const ToolPlacementFlags({
    required this.dashboard,
    required this.drawer,
  });

  factory ToolPlacementFlags.fromJson(Map<String, dynamic> json) {
    return ToolPlacementFlags(
      dashboard: json['dashboard'] as bool? ?? false,
      drawer: json['drawer'] as bool? ?? false,
    );
  }

  final bool dashboard;
  final bool drawer;

  ToolPlacementFlags copyWith({
    bool? dashboard,
    bool? drawer,
  }) {
    return ToolPlacementFlags(
      dashboard: dashboard ?? this.dashboard,
      drawer: drawer ?? this.drawer,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dashboard': dashboard,
        'drawer': drawer,
      };
}

/// Static metadata for a configurable tool (labels may be overridden at runtime for wiki).
class AppToolDefinition {
  const AppToolDefinition({
    required this.id,
    required this.kind,
    required this.icon,
    this.titleKey,
    this.subtitleKey,
  });

  final String id;
  final AppToolKind kind;
  final IconData icon;
  final String? titleKey;
  final String? subtitleKey;
}
