import 'dart:io';

import 'package:disastron/features/wiki/data/wiki_sources_store.dart';
import 'package:disastron/features/wiki/domain/wiki_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wiki.yaml Bundled Assets Validation', () {
    test('should successfully parse the bundled assets/wiki/wiki.yaml file', () {
      final file = File('assets/wiki/wiki.yaml');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'wiki.yaml should exist in assets/wiki/',
      );

      final content = file.readAsStringSync();
      expect(content, isNotEmpty);

      const store = WikiSourcesStore();
      final List<WikiSource> sources = store.parseWikiSourcesFromYaml(content);

      expect(
        sources,
        isNotEmpty,
        reason: 'Parsed wiki sources list should not be empty',
      );

      // Assert that every parsed wiki source has valid required attributes
      for (final source in sources) {
        expect(source.url, isNotEmpty, reason: 'URL should not be empty');
        expect(source.title, isNotEmpty, reason: 'Title should not be empty');
        expect(
          source.category,
          isNotEmpty,
          reason: 'Category should not be empty',
        );
        expect(source.locale, isNotEmpty, reason: 'Locale should not be empty');

        // Ensure URLs are valid Wikipedia mobile links starting with http(s)://
        expect(
          source.url.startsWith('https://') || source.url.startsWith('http://'),
          isTrue,
          reason: 'URL should be a valid HTTP/HTTPS link: ${source.url}',
        );

        // Check if the locale code is supported
        expect(
          ['en', 'de', 'fr', 'es', 'el', 'zh', 'ar'].contains(source.locale),
          isTrue,
          reason:
              'Locale ${source.locale} must be one of the supported locales',
        );
      }

      // Verify we have multiple locales configured
      final locales = sources.map((s) => s.locale).toSet();
      expect(
        locales.length,
        greaterThanOrEqualTo(5),
        reason: 'Should have a diverse set of locales configured',
      );

      // Let's make sure the specific languages are present
      expect(locales.contains('en'), isTrue);
      expect(locales.contains('de'), isTrue);
      expect(locales.contains('fr'), isTrue);
      expect(locales.contains('es'), isTrue);
      expect(locales.contains('zh'), isTrue);
    });
  });
}
