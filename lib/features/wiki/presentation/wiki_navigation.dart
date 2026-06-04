import 'package:disastron/features/wiki/presentation/wiki_article_sheet.dart';
import 'package:disastron/features/wiki/presentation/wiki_models.dart';
import 'package:disastron/features/wiki/presentation/wiki_pack_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens a bundled wiki article by [articleId] (e.g. from dashboard or `wiki:` links).
Future<void> openWikiArticleById(
  BuildContext context,
  WidgetRef ref,
  String articleId,
) async {
  final WikiPack pack = await ref.read(wikiPackProvider.future);
  final WikiArticle? article = pack.articleById(articleId);
  if (!context.mounted) {
    return;
  }
  if (article == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('wiki_article_missing'.tr(args: <String>[articleId])),
      ),
    );
    return;
  }
  await openWikiArticleSheet(
    context,
    title: article.title,
    bodyMarkdown: article.bodyMarkdown,
    svgLabels: pack.svgLabels,
    onWikiLink: (String linkedId) async {
      Navigator.of(context).pop();
      await openWikiArticleById(context, ref, linkedId);
    },
  );
}
