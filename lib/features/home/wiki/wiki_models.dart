import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

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

  static Future<WikiPack> loadBundled() async {
    final String data =
        await rootBundle.loadString('assets/wiki/wiki_pack.json');
    return WikiPack.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }
}
