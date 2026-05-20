import 'dart:convert';

import 'package:disastron/app/app_locales.dart';
import 'package:disastron/core/assets/bundled_asset_io.dart';

class WikiArticle {
  const WikiArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.bodyMarkdown,
  });

  factory WikiArticle.fromJson(Map<String, dynamic> json) {
    return WikiArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      bodyMarkdown: json['bodyMarkdown'] as String,
    );
  }

  final String id;
  final String title;
  final String summary;
  final String bodyMarkdown;
}

class WikiPack {
  const WikiPack({required this.articles});

  factory WikiPack.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = json['articles'] as List<dynamic>;
    return WikiPack(
      articles: raw
          .map((dynamic e) => WikiArticle.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<WikiArticle> articles;

  WikiArticle? articleById(String id) {
    for (final WikiArticle a in articles) {
      if (a.id == id) {
        return a;
      }
    }
    return null;
  }

  /// Loads bundled wiki for [localeCode]; falls back to English asset.
  static Future<WikiPack> loadForLocale(String localeCode) async {
    final String safe = AppLocales.codes.contains(localeCode)
        ? localeCode
        : AppLocales.codes.first;
    try {
      final String data =
          await loadBundledAssetString('assets/wiki/wiki_pack_$safe.json');
      return WikiPack.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      final String data =
          await loadBundledAssetString('assets/wiki/wiki_pack_en.json');
      return WikiPack.fromJson(jsonDecode(data) as Map<String, dynamic>);
    }
  }

  /// Legacy entry point (English).
  static Future<WikiPack> loadBundled() => loadForLocale('en');
}
