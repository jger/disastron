import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Offline wiki article modal — GenUI-style readable sheet.
Future<void> openWikiArticleSheet(
  BuildContext context, {
  required String title,
  required String bodyMarkdown,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, ScrollController sc) => SingleChildScrollView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: MarkdownBody(data: '# $title\n\n$bodyMarkdown'),
      ),
    ),
  );
}
