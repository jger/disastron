import 'dart:io';

import 'package:disastron/features/wiki/domain/wiki_source.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

class WikiSourcesStore {
  const WikiSourcesStore();

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/wiki.yaml');
  }

  /// Loads sources from the local file in application documents directory.
  /// If the local file does not exist, copies the defaults from assets first.
  Future<List<WikiSource>> loadSources() async {
    try {
      final file = await _localFile;
      if (!file.existsSync()) {
        // Copy from asset
        final String defaultYaml =
            await rootBundle.loadString('assets/wiki/wiki.yaml');
        await file.writeAsString(defaultYaml);
      }

      final String contents = await file.readAsString();
      return parseWikiSourcesFromYaml(contents);
    } catch (e) {
      // Return empty if any error occurs
      return [];
    }
  }

  /// Serializes and saves sources to the local file.
  Future<void> saveSources(List<WikiSource> sources) async {
    final file = await _localFile;
    final String yaml = serializeWikiSourcesToYaml(sources);
    await file.writeAsString(yaml);
  }

  /// Helper to parse YAML string into a list of WikiSource.
  List<WikiSource> parseWikiSourcesFromYaml(String content) {
    try {
      final parsed = loadYaml(content);
      if (parsed is! YamlList) {
        return [];
      }
      return parsed
          .map((item) {
            if (item is YamlMap) {
              return WikiSource.fromMap(item);
            }
            return null;
          })
          .whereType<WikiSource>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Helper to serialize a list of WikiSource into YAML string.
  String serializeWikiSourcesToYaml(List<WikiSource> sources) {
    final sb = StringBuffer();
    for (final s in sources) {
      sb
        ..writeln('-')
        ..writeln('  url: "${_escape(s.url)}"')
        ..writeln('  title: "${_escape(s.title)}"')
        ..writeln('  category: "${_escape(s.category)}"')
        ..writeln('  locale: "${_escape(s.locale)}"')
        ..writeln(); // Blank line for readability
    }
    return sb.toString();
  }

  String _escape(String val) {
    return val.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }
}
