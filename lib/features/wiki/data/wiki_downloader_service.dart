import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WikiDownloaderService {
  const WikiDownloaderService();

  /// Downloads a page and all its assets (images and stylesheets) offline.
  /// Strips out JavaScript.
  Future<void> downloadPage(
    String pageUrl, {
    required void Function(double progress) onProgress,
  }) async {
    // 1. Resolve local paths
    final docDir = await getApplicationDocumentsDirectory();
    final urlHash = pageUrl.hashCode.toUnsigned(32).toRadixString(16);
    final targetDir = Directory(
      '${docDir.path}/wiki_offline_downloads/$urlHash',
    );
    final resourcesDir = Directory('${targetDir.path}/resources');

    // Recreate clean directories
    if (targetDir.existsSync()) {
      targetDir.deleteSync(recursive: true);
    }
    targetDir.createSync(recursive: true);
    resourcesDir.createSync(recursive: true);

    // 2. Fetch the HTML
    onProgress(0.05);
    final String rawHtml = await _downloadText(pageUrl);
    onProgress(0.15);

    // 3. Parse and clean HTML
    final document = html_parser.parse(cleanHtml(rawHtml));

    // 4. Gather resources (images, stylesheets)
    final List<_ResourceToDownload> resources = [];

    // Parse stylesheets
    final stylesheets = document.querySelectorAll('link[rel="stylesheet"]');
    for (final link in stylesheets) {
      final href = link.attributes['href'];
      if (href != null && href.trim().isNotEmpty) {
        final resolvedUrl = _resolveUrl(pageUrl, href);
        // Force .css extension for all stylesheets so the WebView identifies
        // them as CSS when loaded locally via file:// protocol.
        const ext = '.css';
        final localFilename =
            '${resolvedUrl.hashCode.toUnsigned(32).toRadixString(16)}$ext';
        resources.add(
          _ResourceToDownload(
            remoteUrl: resolvedUrl,
            localFilename: localFilename,
            element: link,
            attributeName: 'href',
          ),
        );
      }
    }

    // Remove <source> elements inside <picture> tags so the webview falls back to <img> elements
    document.querySelectorAll('picture source').forEach((el) => el.remove());

    // Parse images
    final images = document.querySelectorAll('img');
    for (final img in images) {
      // Wikipedia often uses data-src, data-lazy-src or data-original for lazy loaded images
      final String? src =
          img.attributes['data-src'] ??
          img.attributes['data-lazy-src'] ??
          img.attributes['data-original'] ??
          img.attributes['src'];
      if (src != null && src.trim().isNotEmpty) {
        final resolvedUrl = _resolveUrl(pageUrl, src);
        final ext = _getFilenameExtension(resolvedUrl, defaultExt: '.png');
        final localFilename =
            '${resolvedUrl.hashCode.toUnsigned(32).toRadixString(16)}$ext';
        resources.add(
          _ResourceToDownload(
            remoteUrl: resolvedUrl,
            localFilename: localFilename,
            element: img,
            attributeName: 'src',
          ),
        );
      }

      // Clean up lazy load and responsive attributes so the webview doesn't try to load them from network
      img.attributes.remove('srcset');
      img.attributes.remove('data-src');
      img.attributes.remove('data-srcset');
      img.attributes.remove('data-lazy-src');
      img.attributes.remove('data-original');
    }

    // Parse inline styles for background images
    final styleElements = document.querySelectorAll('*[style]');
    final bgUrlRegex = RegExp(r"""url\s*\(\s*['"]?([^'"\)\s]+)['"]?\s*\)""");
    for (final el in styleElements) {
      final style = el.attributes['style'] ?? '';
      final matches = bgUrlRegex.allMatches(style);
      for (final match in matches) {
        final url = match.group(1);
        if (url != null && url.trim().isNotEmpty) {
          final resolvedUrl = _resolveUrl(pageUrl, url);
          final ext = _getFilenameExtension(resolvedUrl, defaultExt: '.png');
          final localFilename =
              '${resolvedUrl.hashCode.toUnsigned(32).toRadixString(16)}$ext';
          resources.add(
            _ResourceToDownload(
              remoteUrl: resolvedUrl,
              localFilename: localFilename,
              element: el,
              attributeName: 'style',
              originalUrlInAttribute: url,
            ),
          );
        }
      }
    }

    // Parse CSS styles in style elements
    final styleTags = document.querySelectorAll('style');
    for (final styleTag in styleTags) {
      final text = styleTag.text;
      final matches = bgUrlRegex.allMatches(text);
      for (final match in matches) {
        final url = match.group(1);
        if (url != null && url.trim().isNotEmpty) {
          final resolvedUrl = _resolveUrl(pageUrl, url);
          final ext = _getFilenameExtension(resolvedUrl, defaultExt: '.png');
          final localFilename =
              '${resolvedUrl.hashCode.toUnsigned(32).toRadixString(16)}$ext';
          resources.add(
            _ResourceToDownload(
              remoteUrl: resolvedUrl,
              localFilename: localFilename,
              element: styleTag,
              attributeName: 'text',
              originalUrlInAttribute: url,
            ),
          );
        }
      }
    }

    // 6. Download all resources and rewrite attributes
    if (resources.isEmpty) {
      onProgress(0.9);
    } else {
      const double progressStart = 0.15;
      const double progressWeight = 0.75;

      for (int i = 0; i < resources.length; i++) {
        final res = resources[i];
        try {
          final file = File('${resourcesDir.path}/${res.localFilename}');
          final bytes = await _downloadBytes(res.remoteUrl);
          await file.writeAsBytes(bytes);

          // Rewrite path in HTML to point to local relative location
          if (res.attributeName == 'text') {
            res.element.text = res.element.text.replaceAll(
              res.originalUrlInAttribute!,
              './resources/${res.localFilename}',
            );
          } else if (res.attributeName == 'style') {
            final style = res.element.attributes['style'] ?? '';
            res.element.attributes['style'] = style.replaceAll(
              res.originalUrlInAttribute!,
              './resources/${res.localFilename}',
            );
          } else {
            res.element.attributes[res.attributeName] =
                './resources/${res.localFilename}';
          }
        } catch (e) {
          // Robustness: if an image or CSS download fails, we point it to # or fallback
          // and log it, rather than failing the entire page download.
          stderr.writeln(
            'Offline Scraper: Failed to download resource ${res.remoteUrl}: $e',
          );
        }

        final double currentProgress =
            progressStart + ((i + 1) / resources.length) * progressWeight;
        onProgress(currentProgress);
      }
    }

    // 7. Save the modified HTML page
    final htmlFile = File('${targetDir.path}/index.html');
    await htmlFile.writeAsString(document.outerHtml);
    onProgress(1);
  }

  /// Deletes the downloaded files for a page URL
  Future<void> deleteOfflinePage(String pageUrl) async {
    final docDir = await getApplicationDocumentsDirectory();
    final urlHash = pageUrl.hashCode.toUnsigned(32).toRadixString(16);
    final targetDir = Directory(
      '${docDir.path}/wiki_offline_downloads/$urlHash',
    );
    if (targetDir.existsSync()) {
      await targetDir.delete(recursive: true);
    }
  }

  /// Checks if a page URL is downloaded and exists offline
  Future<bool> isPageDownloaded(String pageUrl) async {
    final docDir = await getApplicationDocumentsDirectory();
    final urlHash = pageUrl.hashCode.toUnsigned(32).toRadixString(16);
    final htmlFile = File(
      '${docDir.path}/wiki_offline_downloads/$urlHash/index.html',
    );
    return htmlFile.existsSync();
  }

  /// Calculates total size of downloaded files (HTML + resources) in MBs
  Future<double> getPageDirectorySizeMB(String pageUrl) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final urlHash = pageUrl.hashCode.toUnsigned(32).toRadixString(16);
      final targetDir = Directory(
        '${docDir.path}/wiki_offline_downloads/$urlHash',
      );
      if (!targetDir.existsSync()) {
        return 0.0;
      }
      int totalBytes = 0;
      final entities = targetDir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          totalBytes += entity.lengthSync();
        }
      }
      return totalBytes / (1024 * 1024);
    } catch (_) {
      return 0.0;
    }
  }

  /// Parses HTML and removes all scripts, inline javascript event handlers,
  /// and javascript: link targets.
  String cleanHtml(String rawHtml) {
    final document = html_parser.parse(rawHtml);
    // Remove script tags
    document.querySelectorAll('script').forEach((e) => e.remove());
    // Remove inline JS handlers and javascript: URLs
    document.querySelectorAll('*').forEach((element) {
      final keysToRemove = <dynamic>[];
      element.attributes.forEach((key, value) {
        final keyStr = key.toString().toLowerCase();
        if (keyStr.startsWith('on')) {
          keysToRemove.add(key);
        }
        final valStr = value.toLowerCase();
        if (valStr.startsWith('javascript:')) {
          element.attributes[key] = '#';
        }
      });
      for (final key in keysToRemove) {
        element.attributes.remove(key);
      }
    });
    return document.outerHtml;
  }

  // --- Network Helpers ---

  Future<List<int>> _downloadBytes(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download: $url (Status: ${response.statusCode})',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  Future<String> _downloadText(String url) async {
    final bytes = await _downloadBytes(url);
    return utf8.decode(bytes, allowMalformed: true);
  }

  // --- URL Helpers ---

  String _resolveUrl(String baseUrl, String relativeUrl) {
    // Trim spaces
    final trimmed = relativeUrl.trim();
    // Protocol-relative URLs (e.g. //upload.wikimedia.org/...)
    if (trimmed.startsWith('//')) {
      final baseUri = Uri.parse(baseUrl);
      return '${baseUri.scheme}:$trimmed';
    }
    try {
      return Uri.parse(baseUrl).resolve(trimmed).toString();
    } catch (_) {
      return trimmed;
    }
  }

  String _getFilenameExtension(String url, {required String defaultExt}) {
    try {
      final uri = Uri.parse(url);
      final ext = p.extension(uri.path);
      if (ext.isNotEmpty) {
        return ext.split('?').first; // Strip query parameters
      }
    } catch (_) {}
    return defaultExt;
  }
}

class _ResourceToDownload {
  _ResourceToDownload({
    required this.remoteUrl,
    required this.localFilename,
    required this.element,
    required this.attributeName,
    this.originalUrlInAttribute,
  });
  final String remoteUrl;
  final String localFilename;
  final html_dom.Element element;
  final String attributeName;
  final String? originalUrlInAttribute;
}
