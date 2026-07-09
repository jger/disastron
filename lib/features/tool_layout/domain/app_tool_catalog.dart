// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/tool_layout/domain/app_tool.dart';
import 'package:flutter/material.dart';

/// Single source for tool ids, ordering, and static labels.
abstract final class AppToolCatalog {
  AppToolCatalog._();

  static const String callHelpId = 'call_help';
  static const String sosId = 'sos';
  static const String appearanceSettingsId = 'appearance_settings';
  static const String offlineModelId = 'offline_model';
  static const String aboutId = 'about';

  /// Matches [assets/wiki/manifest.yaml] article order.
  static const List<String> wikiArticleIds = <String>[
    'general_safety',
    'evacuation',
    'first_aid_bleeding',
    'fire_smoke',
    'earthquake',
    'flood',
    'communication_plan',
    'trip_planning',
    'karpa_cpr',
    'karpa_aed',
    'morse_code',
  ];

  static const List<String> quickActionIds = <String>[callHelpId, sosId];

  static const List<String> settingsIds = <String>[
    appearanceSettingsId,
    offlineModelId,
    aboutId,
  ];

  /// Tools the user can place on dashboard/drawer (settings stay fixed in drawer).
  static const List<String> placementConfigurableIds = <String>[
    ...quickActionIds,
    ...wikiArticleIds,
  ];

  static const Map<String, AppToolDefinition> definitions =
      <String, AppToolDefinition>{
        callHelpId: AppToolDefinition(
          id: callHelpId,
          kind: AppToolKind.quickAction,
          icon: Icons.emergency_share_outlined,
          titleKey: 'dashboard_call_help_title',
          subtitleKey: 'dashboard_call_help_subtitle',
        ),
        sosId: AppToolDefinition(
          id: sosId,
          kind: AppToolKind.quickAction,
          icon: Icons.sos,
          titleKey: 'dashboard_sos_title',
          subtitleKey: 'dashboard_sos_subtitle',
        ),
        appearanceSettingsId: AppToolDefinition(
          id: appearanceSettingsId,
          kind: AppToolKind.settings,
          icon: Icons.settings_outlined,
          titleKey: 'drawer_theme',
          subtitleKey: 'tool_layout_settings_subtitle',
        ),
        offlineModelId: AppToolDefinition(
          id: offlineModelId,
          kind: AppToolKind.settings,
          icon: Icons.psychology_outlined,
          titleKey: 'drawer_offline_model',
          subtitleKey: 'tool_layout_offline_model_subtitle',
        ),
        aboutId: AppToolDefinition(
          id: aboutId,
          kind: AppToolKind.settings,
          icon: Icons.info_outline,
          titleKey: 'drawer_about',
          subtitleKey: 'tool_layout_about_subtitle',
        ),
        'karpa_cpr': AppToolDefinition(
          id: 'karpa_cpr',
          kind: AppToolKind.wikiArticle,
          icon: Icons.favorite_border,
          titleKey: 'dashboard_cpr_title',
          subtitleKey: 'dashboard_cpr_subtitle',
        ),
        'trip_planning': AppToolDefinition(
          id: 'trip_planning',
          kind: AppToolKind.wikiArticle,
          icon: Icons.luggage_outlined,
          titleKey: 'dashboard_planning_title',
          subtitleKey: 'dashboard_planning_subtitle',
        ),
      };

  static AppToolDefinition definitionFor(String toolId) {
    return definitions[toolId] ??
        AppToolDefinition(
          id: toolId,
          kind: AppToolKind.wikiArticle,
          icon: Icons.menu_book_outlined,
        );
  }

  static AppToolKind kindFor(String toolId) {
    return definitionFor(toolId).kind;
  }

  static bool isWikiArticle(String toolId) {
    return wikiArticleIds.contains(toolId);
  }

  /// Quick actions that must stay on dashboard and/or drawer.
  static const Set<String> mustStayReachableIds = <String>{callHelpId, sosId};

  static List<String> idsForSurface(
    Map<String, ToolPlacementFlags> placements,
    AppToolSurface surface,
  ) {
    final bool Function(ToolPlacementFlags) pick = switch (surface) {
      AppToolSurface.dashboard => (ToolPlacementFlags f) => f.dashboard,
      AppToolSurface.drawer => (ToolPlacementFlags f) => f.drawer,
    };

    final List<String> out = <String>[];
    for (final String id in quickActionIds) {
      if (pick(
        placements[id] ??
            const ToolPlacementFlags(dashboard: false, drawer: false),
      )) {
        out.add(id);
      }
    }
    for (final String id in wikiArticleIds) {
      if (pick(
        placements[id] ??
            const ToolPlacementFlags(dashboard: false, drawer: false),
      )) {
        out.add(id);
      }
    }
    return out;
  }
}
