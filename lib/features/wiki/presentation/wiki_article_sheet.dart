import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:svg_flutter/svg_flutter.dart';

/// Scheme for cross-links between wiki articles: `[label](wiki:article_id)`.
const String kWikiLinkScheme = 'wiki:';

/// Offline wiki article modal — GenUI-style readable sheet.
Future<void> openWikiArticleSheet(
  BuildContext context, {
  required String title,
  required String bodyMarkdown,
  Future<void> Function(String articleId)? onWikiLink,
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
        child: MarkdownBody(
          data: '# $title\n\n$bodyMarkdown',
          onTapLink: (String linkText, String? href, String _) {
            if (href == null ||
                !href.startsWith(kWikiLinkScheme) ||
                onWikiLink == null) {
              return;
            }
            final String articleId = href.substring(kWikiLinkScheme.length);
            if (articleId.isEmpty) {
              return;
            }
            onWikiLink(articleId);
          },
          sizedImageBuilder: (MarkdownImageConfig config) {
            final uriString = config.uri.toString();
            final isSvg = uriString.toLowerCase().endsWith('.svg');

            if (isSvg) {
              return FutureBuilder<String>(
                future: rootBundle.loadString(uriString),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    var svgString = snapshot.data!;
                    final RegExp slugRegex = RegExp(r'\{\{([\w_]+)\}\}');
                    svgString = svgString.replaceAllMapped(slugRegex, (match) {
                      final key = match.group(1);
                      return key != null ? tr(key) : '';
                    });

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SvgPicture.string(svgString),
                      ),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                },
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(uriString),
              ),
            );
          },
        ),
      ),
    ),
  );
}
