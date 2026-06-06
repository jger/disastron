// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:disastron/app/locale_provider.dart';
import 'package:disastron/features/wiki/domain/wiki_source.dart';
import 'package:disastron/features/wiki/presentation/wiki_download_provider.dart';
import 'package:disastron/features/wiki/presentation/wiki_models.dart';
import 'package:disastron/features/wiki/presentation/wiki_navigation.dart';
import 'package:disastron/features/wiki/presentation/wiki_pack_provider.dart';
import 'package:disastron/features/wiki/presentation/wiki_sources_provider.dart';
import 'package:disastron/router/routes.gr.dart';
import 'package:disastron/shared/widgets/genui_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final wikiSearchActiveProvider = StateProvider<bool>((ref) => false);
final wikiSearchQueryProvider = StateProvider<String>((ref) => '');

@RoutePage()
class WikiPage extends HookConsumerWidget {
  const WikiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = useState(0); // 0 = Bundled, 1 = Web Wiki
    final AsyncValue<WikiPack> packAsync = ref.watch(wikiPackProvider);
    final sourcesAsync = ref.watch(wikiSourcesProvider);
    final downloadsAsync = ref.watch(wikiDownloadProvider);
    final localeAsync = ref.watch(appLocaleProvider);
    final searchQuery = ref.watch(wikiSearchQueryProvider);

    final String currentLocale = localeAsync.maybeWhen(
      data: (s) => s.localeCode,
      orElse: () => 'en',
    );

    return packAsync.when(
      data: (WikiPack pack) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'wiki_title'.tr(),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'wiki_subtitle'.tr(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSegmentedControl(context, selectedTab),
            const SizedBox(height: 16),
            if (selectedTab.value == 0)
              ..._buildBundledSection(context, ref, pack, searchQuery)
            else
              ..._buildWebSection(
                context,
                ref,
                sourcesAsync,
                downloadsAsync,
                currentLocale,
                searchQuery,
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(
        child: Text('wiki_load_error'.tr(args: <String>['$e'])),
      ),
    );
  }

  Widget _buildSegmentedControl(
    BuildContext context,
    ValueNotifier<int> selectedTab,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => selectedTab.value = 0,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selectedTab.value == 0
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'wiki_tab_bundled'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selectedTab.value == 0
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => selectedTab.value = 1,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selectedTab.value == 1
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'wiki_tab_web'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selectedTab.value == 1
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBundledSection(
    BuildContext context,
    WidgetRef ref,
    WikiPack pack,
    String searchQuery,
  ) {
    final query = searchQuery.trim().toLowerCase();
    final filteredArticles = pack.articles.where((a) {
      if (query.isEmpty) return true;
      return a.title.toLowerCase().contains(query) ||
          a.summary.toLowerCase().contains(query);
    }).toList();

    if (filteredArticles.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                Icons.search_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 12),
              Text(
                'wiki_search_no_results'.tr(args: [searchQuery]),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }

    return filteredArticles
        .map(
          (WikiArticle a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GenUiCard(
              title: a.title,
              subtitle: a.summary.isEmpty ? null : a.summary,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openWikiArticleById(context, ref, a.id),
                  icon: const Icon(Icons.article_outlined),
                  label: Text('wiki_read'.tr()),
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildWebSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<WikiSource>> sourcesAsync,
    AsyncValue<Map<String, WikiDownloadState>> downloadsAsync,
    String locale,
    String searchQuery,
  ) {
    return [
      sourcesAsync.when(
        data: (sources) {
          final localSources =
              sources.where((s) => s.locale == locale).toList();

          if (localSources.isEmpty) {
            return Column(
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'wiki_no_web_sources'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.router.push(const WikiConfigRoute()),
                  icon: const Icon(Icons.settings_suggest_outlined),
                  label: Text('wiki_configure_sources'.tr()),
                ),
              ],
            );
          }

          final filteredSources = localSources.where((s) {
            final query = searchQuery.trim().toLowerCase();
            if (query.isEmpty) return true;
            return s.title.toLowerCase().contains(query) ||
                (Uri.tryParse(s.url)?.host.toLowerCase().contains(query) ??
                    false) ||
                s.category.toLowerCase().contains(query);
          }).toList();

          // Group by category
          final Map<String, List<WikiSource>> grouped = {};
          for (final s in filteredSources) {
            grouped.putIfAbsent(s.category, () => []).add(s);
          }

          final downloads = downloadsAsync.value ?? {};

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'wiki_web_sources_title'.tr(args: [locale.toUpperCase()]),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'wiki_download_all'.tr(),
                        icon: const Icon(Icons.cloud_download_outlined),
                        onPressed: () {
                          for (final s in localSources) {
                            final status = downloads[s.url]?.status ??
                                WikiDownloadStatus.notDownloaded;
                            if (status == WikiDownloadStatus.notDownloaded ||
                                status == WikiDownloadStatus.failed) {
                              ref
                                  .read(wikiDownloadProvider.notifier)
                                  .downloadPage(s);
                            }
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'wiki_configure_sources'.tr(),
                        icon: const Icon(Icons.settings_suggest_rounded),
                        onPressed: () =>
                            context.router.push(const WikiConfigRoute()),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredSources.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'wiki_search_no_results'.tr(args: [searchQuery]),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...grouped.entries.map((entry) {
                  final category = entry.key;
                  final catSources = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 8, bottom: 8, left: 4),
                        child: Text(
                          category,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              for (int i = 0; i < catSources.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                _buildWebPageItem(
                                  context,
                                  ref,
                                  catSources[i],
                                  downloads[catSources[i].url] ??
                                      const WikiDownloadState(
                                        status:
                                            WikiDownloadStatus.notDownloaded,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('wiki_load_error'.tr(args: [err.toString()]))),
      ),
    ];
  }

  Widget _buildWebPageItem(
    BuildContext context,
    WidgetRef ref,
    WikiSource s,
    WikiDownloadState dlState,
  ) {
    final host = Uri.tryParse(s.url)?.host ?? '';
    final isDownloaded = dlState.status == WikiDownloadStatus.downloaded;
    final isDownloading = dlState.status == WikiDownloadStatus.downloading;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Tinted icon container representing source status
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDownloaded
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDownloaded ? Icons.offline_pin_rounded : Icons.language_rounded,
              color: isDownloaded
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          // Title and Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      host,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (isDownloaded) ...[
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${dlState.sizeMB.toStringAsFixed(2)} MB',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ],
                ),
                if (isDownloading) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: dlState.progress,
                      minHeight: 4,
                    ),
                  ),
                ] else if (dlState.status == WikiDownloadStatus.failed) ...[
                  const SizedBox(height: 4),
                  Text(
                    'wiki_download_failed'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Action Buttons
          _buildActionButtons(context, ref, s, dlState),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    WikiSource source,
    WikiDownloadState dlState,
  ) {
    switch (dlState.status) {
      case WikiDownloadStatus.notDownloaded:
      case WikiDownloadStatus.failed:
        return IconButton.filledTonal(
          tooltip: 'wiki_download'.tr(),
          icon: const Icon(Icons.cloud_download_outlined, size: 20),
          onPressed: () =>
              ref.read(wikiDownloadProvider.notifier).downloadPage(source),
        );
      case WikiDownloadStatus.downloading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case WikiDownloadStatus.downloaded:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              tooltip: 'wiki_view'.tr(),
              icon: const Icon(Icons.open_in_new_outlined, size: 20),
              onPressed: () => context.router.push(
                WikiWebviewRoute(url: source.url, title: source.title),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'sync') {
                  unawaited(
                    ref
                        .read(wikiDownloadProvider.notifier)
                        .downloadPage(source),
                  );
                } else if (value == 'delete') {
                  final bool? ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('wiki_delete_offline_title'.tr()),
                      content: Text(
                        'wiki_delete_offline_message'.tr(args: [source.title]),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('cancel'.tr()),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            foregroundColor:
                                Theme.of(context).colorScheme.onError,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('remove'.tr()),
                        ),
                      ],
                    ),
                  );
                  if (ok ?? false) {
                    await ref
                        .read(wikiDownloadProvider.notifier)
                        .deleteDownloadedPage(source);
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'sync',
                  child: Row(
                    children: [
                      Icon(
                        Icons.sync,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'wiki_sync'.tr(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'wiki_delete'.tr(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }
}
