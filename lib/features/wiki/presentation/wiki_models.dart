import 'package:disastron/features/wiki/presentation/wiki_pack_loader.dart';

class WikiArticle {
  const WikiArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.bodyMarkdown,
  });

  final String id;
  final String title;
  final String summary;
  final String bodyMarkdown;
}

class WikiPack {
  const WikiPack({
    required this.articles,
    this.svgLabels = const <String, String>{},
  });

  final List<WikiArticle> articles;
  final Map<String, String> svgLabels;

  WikiArticle? articleById(String id) {
    for (final WikiArticle a in articles) {
      if (a.id == id) {
        return a;
      }
    }
    return null;
  }

  /// Loads bundled wiki for [localeCode]; falls back to English pack.
  static Future<WikiPack> loadForLocale(String localeCode) =>
      WikiPackLoader.loadForLocale(localeCode);

  /// Legacy entry point (English).
  static Future<WikiPack> loadBundled() => loadForLocale('en');
}
