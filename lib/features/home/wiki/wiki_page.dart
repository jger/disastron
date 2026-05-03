/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/home/wiki/wiki_article_sheet.dart';
import 'package:disastron/features/home/wiki/wiki_models.dart';
import 'package:disastron/shared/widgets/genui_card.dart';
import 'package:flutter/material.dart';

@RoutePage()
class WikiPage extends StatefulWidget {
  const WikiPage({super.key});

  @override
  State<WikiPage> createState() => _WikiPageState();
}

class _WikiPageState extends State<WikiPage> {
  late Future<WikiPack> _future;

  @override
  void initState() {
    super.initState();
    _future = WikiPack.loadBundled();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WikiPack>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<WikiPack> snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load wiki: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final WikiPack pack = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Wiki', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Offline emergency reference. Not a substitute for professional services.',
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
                      label: const Text('Read'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
