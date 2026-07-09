// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/tool_layout/domain/app_tool.dart';
import 'package:disastron/features/tool_layout/domain/app_tool_catalog.dart';
import 'package:disastron/features/wiki/presentation/wiki_models.dart';
import 'package:easy_localization/easy_localization.dart';

class ToolLayoutLabels {
  const ToolLayoutLabels({required this.title, this.subtitle});

  final String title;
  final String? subtitle;
}

ToolLayoutLabels labelsForTool(String toolId, {WikiPack? wikiPack}) {
  final AppToolDefinition def = AppToolCatalog.definitionFor(toolId);
  if (def.titleKey != null) {
    return ToolLayoutLabels(
      title: def.titleKey!.tr(),
      subtitle: def.subtitleKey?.tr(),
    );
  }
  if (AppToolCatalog.isWikiArticle(toolId) && wikiPack != null) {
    final WikiArticle? article = wikiPack.articleById(toolId);
    if (article != null) {
      return ToolLayoutLabels(
        title: article.title,
        subtitle: article.summary.isEmpty ? null : article.summary,
      );
    }
  }
  return ToolLayoutLabels(title: toolId);
}
