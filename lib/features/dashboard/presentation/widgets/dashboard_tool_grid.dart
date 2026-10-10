// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/dashboard/presentation/widgets/dashboard_action_card.dart';
import 'package:disastron/features/home/home.dart';
import 'package:disastron/features/tool_layout/tool_layout.dart';
import 'package:disastron/features/wiki/wiki.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardToolGrid extends ConsumerWidget {
  const DashboardToolGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, ToolPlacementFlags>> placementsAsync = ref
        .watch(toolPlacementsProvider);
    final AsyncValue<WikiPack> wikiAsync = ref.watch(wikiPackProvider);

    return placementsAsync.when(
      data: (Map<String, ToolPlacementFlags> placements) {
        return wikiAsync.when(
          data: (WikiPack wikiPack) {
            final List<String> toolIds = AppToolCatalog.idsForSurface(
              placements,
              AppToolSurface.dashboard,
            );
            if (toolIds.isEmpty) {
              return const SizedBox.shrink();
            }
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double w = c.maxWidth;
                final int cols = w >= 520 ? 3 : 2;
                final List<Widget> cards = toolIds.map((String toolId) {
                  final AppToolDefinition def = AppToolCatalog.definitionFor(
                    toolId,
                  );
                  final ToolLayoutLabels labels = labelsForTool(
                    toolId,
                    wikiPack: wikiPack,
                  );
                  return DashboardActionCard(
                    icon: def.icon,
                    title: labels.title,
                    subtitle: labels.subtitle ?? '',
                    onTap: () => openAppTool(context, ref, toolId),
                  );
                }).toList();
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3 / 2,
                  children: cards,
                );
              },
            );
          },
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
