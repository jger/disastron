// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/tool_layout/domain/app_tool.dart';
import 'package:disastron/features/tool_layout/domain/app_tool_catalog.dart';
import 'package:disastron/features/tool_layout/domain/tool_placement_logic.dart';
import 'package:disastron/features/tool_layout/presentation/tool_layout_labels.dart';
import 'package:disastron/features/tool_layout/presentation/tool_placements_provider.dart';
import 'package:disastron/features/wiki/presentation/wiki_models.dart';
import 'package:disastron/features/wiki/presentation/wiki_pack_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class ToolLayoutSettingsPage extends ConsumerWidget {
  const ToolLayoutSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, ToolPlacementFlags>> placementsAsync =
        ref.watch(toolPlacementsProvider);
    final AsyncValue<WikiPack> wikiAsync = ref.watch(wikiPackProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('tool_layout_title'.tr()),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await ref.read(toolPlacementsProvider.notifier).resetToDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('tool_layout_reset_done'.tr())),
                );
              }
            },
            child: Text('tool_layout_reset'.tr()),
          ),
        ],
      ),
      body: placementsAsync.when(
        data: (Map<String, ToolPlacementFlags> placements) {
          return wikiAsync.when(
            data: (WikiPack wikiPack) => _ToolLayoutTable(
              placements: placements,
              wikiPack: wikiPack,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace _) => Center(
              child: Text('wiki_load_error'.tr(args: <String>['$e'])),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _ToolLayoutTable extends ConsumerWidget {
  const _ToolLayoutTable({
    required this.placements,
    required this.wikiPack,
  });

  final Map<String, ToolPlacementFlags> placements;
  final WikiPack wikiPack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'tool_layout_intro'.tr(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(3),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
          children: <TableRow>[
            TableRow(
              children: <Widget>[
                _headerCell(context, 'tool_layout_col_tool'.tr()),
                _headerCell(context, 'tool_layout_col_dashboard'.tr()),
                _headerCell(context, 'tool_layout_col_drawer'.tr()),
              ],
            ),
            _sectionRow(context, 'tool_layout_section_quick'.tr()),
            ..._rowsForIds(
              context,
              ref,
              AppToolCatalog.quickActionIds,
            ),
            _sectionRow(context, 'tool_layout_section_settings'.tr()),
            ..._rowsForIds(
              context,
              ref,
              AppToolCatalog.settingsIds,
            ),
            _sectionRow(context, 'tool_layout_section_wiki'.tr()),
            ..._rowsForIds(
              context,
              ref,
              AppToolCatalog.wikiArticleIds,
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerCell(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }

  TableRow _sectionRow(BuildContext context, String title) {
    return TableRow(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox.shrink(),
        const SizedBox.shrink(),
      ],
    );
  }

  List<TableRow> _rowsForIds(
    BuildContext context,
    WidgetRef ref,
    List<String> ids,
  ) {
    return ids.map((String toolId) {
      final ToolPlacementFlags flags = placements[toolId] ??
          const ToolPlacementFlags(dashboard: false, drawer: false);
      final ToolLayoutLabels labels = labelsForTool(
        toolId,
        wikiPack: wikiPack,
      );
      return TableRow(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(labels.title),
                if (labels.subtitle != null)
                  Text(
                    labels.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          Checkbox(
            value: flags.dashboard,
            onChanged: (bool? v) => _onToggle(
              context,
              ref,
              toolId,
              AppToolSurface.dashboard,
              v ?? false,
            ),
          ),
          Checkbox(
            value: flags.drawer,
            onChanged: (bool? v) => _onToggle(
              context,
              ref,
              toolId,
              AppToolSurface.drawer,
              v ?? false,
            ),
          ),
        ],
      );
    }).toList();
  }

  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    String toolId,
    AppToolSurface surface,
    bool value,
  ) async {
    final ToolPlacementValidation result =
        await ref.read(toolPlacementsProvider.notifier).setPlacement(
              toolId: toolId,
              surface: surface,
              value: value,
            );
    if (!context.mounted) {
      return;
    }
    if (!result.isOk && result.messageKey != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.messageKey!.tr())),
      );
    }
  }
}
