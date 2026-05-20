/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/home/wiki/wiki_article_sheet.dart';
import 'package:disastron/features/home/wiki/wiki_models.dart';
import 'package:disastron/features/home/wiki/wiki_pack_provider.dart';
import 'package:disastron/shared/widgets/genui_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class WikiPage extends ConsumerWidget {
  const WikiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WikiPack> packAsync = ref.watch(wikiPackProvider);
    return packAsync.when(
      data: (WikiPack pack) => ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('wiki_title'.tr(), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'wiki_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          ...pack.articles.map(
            (WikiArticle a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GenUiCard(
                title: a.title,
                subtitle: a.summary.isEmpty ? null : a.summary,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => openWikiArticleSheet(
                      context,
                      title: a.title,
                      bodyMarkdown: a.bodyMarkdown,
                    ),
                    icon: const Icon(Icons.article_outlined),
                    label: Text('wiki_read'.tr()),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(
        child: Text('wiki_load_error'.tr(args: <String>['$e'])),
      ),
    );
  }
}
