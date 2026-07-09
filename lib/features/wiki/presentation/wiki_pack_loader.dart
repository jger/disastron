import 'dart:convert';

import 'package:disastron/app/app_locales.dart';
import 'package:disastron/core/assets/bundled_asset_io.dart';
import 'package:disastron/features/wiki/presentation/wiki_models.dart';
import 'package:yaml/yaml.dart';

const String kWikiManifestPath = 'assets/wiki/manifest.yaml';
const String kWikiLocaleFallback = 'en';

/// Loads folder-based wiki packs: manifest + per-locale `.md` + `svg/*.json`.
abstract final class WikiPackLoader {
  WikiPackLoader._();

  static Future<WikiPack> loadForLocale(String localeCode) async {
    final String locale = AppLocales.codes.contains(localeCode)
        ? localeCode
        : kWikiLocaleFallback;
    try {
      return await _loadPack(locale);
    } catch (_) {
      if (locale == kWikiLocaleFallback) {
        rethrow;
      }
      return _loadPack(kWikiLocaleFallback);
    }
  }

  static Future<WikiPack> _loadPack(String locale) async {
    final _WikiManifest manifest = await _loadManifest();
    final List<WikiArticle> articles = <WikiArticle>[];
    for (final String id in manifest.articleIds) {
      articles.add(await _loadArticle(locale: locale, id: id));
    }
    final Map<String, String> svgLabels = await _loadSvgLabels(
      locale: locale,
      manifest: manifest,
    );
    return WikiPack(articles: articles, svgLabels: svgLabels);
  }

  static Future<_WikiManifest> _loadManifest() async {
    final String raw = await loadBundledAssetString(kWikiManifestPath);
    final Object? decoded = loadYaml(raw);
    if (decoded is! YamlMap) {
      throw const FormatException('Expected YAML map at $kWikiManifestPath');
    }
    final Object? articlesNode = decoded['articles'];
    if (articlesNode is! YamlList) {
      throw const FormatException('Expected "articles" list in wiki manifest');
    }
    final List<String> articleIds = articlesNode
        .map((Object? e) => e.toString())
        .toList(growable: false);

    final List<_SvgAssetEntry> svgAssets = <_SvgAssetEntry>[];
    final Object? svgNode = decoded['svg_assets'];
    if (svgNode is YamlList) {
      for (final Object? item in svgNode) {
        if (item is! YamlMap) {
          continue;
        }
        final String? labels = item['labels']?.toString();
        if (labels == null || labels.isEmpty) {
          continue;
        }
        svgAssets.add(_SvgAssetEntry(labelsPath: labels));
      }
    }
    return _WikiManifest(articleIds: articleIds, svgAssets: svgAssets);
  }

  static Future<WikiArticle> _loadArticle({
    required String locale,
    required String id,
  }) async {
    final String? raw = await _tryLoadLocaleAsset(locale, '$id.md');
    final String content =
        raw ?? (await _loadLocaleAsset(kWikiLocaleFallback, '$id.md'));
    final _ParsedMarkdown parsed = _parseMarkdownWithFrontmatter(content);
    return WikiArticle(
      id: id,
      title: parsed.title,
      summary: parsed.summary,
      bodyMarkdown: parsed.body,
    );
  }

  static Future<Map<String, String>> _loadSvgLabels({
    required String locale,
    required _WikiManifest manifest,
  }) async {
    final Map<String, String> merged = <String, String>{};
    for (final _SvgAssetEntry entry in manifest.svgAssets) {
      final Map<String, String>? labels = await _tryLoadSvgLabelJson(
        locale: locale,
        labelsPath: entry.labelsPath,
      );
      if (labels != null) {
        merged.addAll(labels);
      }
    }
    return merged;
  }

  static Future<Map<String, String>?> _tryLoadSvgLabelJson({
    required String locale,
    required String labelsPath,
  }) async {
    final String? raw = await _tryLoadLocaleAsset(locale, labelsPath);
    final String? content =
        raw ??
        (locale == kWikiLocaleFallback
            ? null
            : await _tryLoadLocaleAsset(kWikiLocaleFallback, labelsPath));
    if (content == null) {
      return null;
    }
    final Object? decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Expected JSON object at wiki $labelsPath');
    }
    return decoded.map(
      (String key, dynamic value) =>
          MapEntry<String, String>(key, value.toString()),
    );
  }

  static Future<String> _loadLocaleAsset(String locale, String relativePath) {
    return loadBundledAssetString(_localeAssetPath(locale, relativePath));
  }

  static Future<String?> _tryLoadLocaleAsset(
    String locale,
    String relativePath,
  ) async {
    try {
      return await loadBundledAssetString(
        _localeAssetPath(locale, relativePath),
      );
    } on Object {
      return null;
    }
  }

  static String _localeAssetPath(String locale, String relativePath) {
    return 'assets/wiki/$locale/$relativePath';
  }

  static _ParsedMarkdown _parseMarkdownWithFrontmatter(String raw) {
    if (!raw.startsWith('---')) {
      return _ParsedMarkdown(title: '', summary: '', body: raw.trim());
    }
    final int end = raw.indexOf('---', 3);
    if (end < 0) {
      return _ParsedMarkdown(title: '', summary: '', body: raw.trim());
    }
    final String yamlBlock = raw.substring(3, end).trim();
    final String body = raw.substring(end + 3).trimLeft();
    final Object? meta = loadYaml(yamlBlock);
    if (meta is! YamlMap) {
      return _ParsedMarkdown(title: '', summary: '', body: body);
    }
    return _ParsedMarkdown(
      title: meta['title']?.toString() ?? '',
      summary: meta['summary']?.toString() ?? '',
      body: body,
    );
  }
}

final class _WikiManifest {
  const _WikiManifest({required this.articleIds, required this.svgAssets});

  final List<String> articleIds;
  final List<_SvgAssetEntry> svgAssets;
}

final class _SvgAssetEntry {
  const _SvgAssetEntry({required this.labelsPath});

  final String labelsPath;
}

final class _ParsedMarkdown {
  const _ParsedMarkdown({
    required this.title,
    required this.summary,
    required this.body,
  });

  final String title;
  final String summary;
  final String body;
}
