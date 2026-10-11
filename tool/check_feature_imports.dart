// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'dart:io';

/// Enforces feature import boundaries (see .cursor/rules/feature-first-riverpod.mdc).
void main() {
  final Directory lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('Run from repo root (lib/ not found).');
    exit(2);
  }

  final List<String> violations = <String>[];

  for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.contains('.g.dart') || entity.path.contains('.gr.dart')) {
      continue;
    }
    final String path = entity.path.replaceAll(r'\', '/');
    final String? ownerFeature = _featureFromPath(path);
    final String content = entity.readAsStringSync();
    for (final String line in content.split('\n')) {
      final String? import = _packageImport(line);
      if (import == null) {
        continue;
      }
      if (!import.startsWith('package:disastron/features/')) {
        continue;
      }
      final String tail = import.substring(
        'package:disastron/features/'.length,
      );
      final int slash = tail.indexOf('/');
      if (slash < 0) {
        continue;
      }
      final String targetFeature = tail.substring(0, slash);
      final String rest = tail.substring(slash + 1);

      if (ownerFeature == null) {
        // core, shared, app, router, main
        if (path.startsWith('lib/core/') || path.startsWith('lib/shared/')) {
          violations.add(
            '$path: core/shared must not import features ($import)',
          );
        }
        continue;
      }

      if (targetFeature == ownerFeature) {
        if (path.contains('/data/') && rest.startsWith('presentation/')) {
          violations.add('$path: data must not import presentation ($import)');
        }
        continue;
      }

      final bool isBarrel = rest == '$targetFeature.dart';
      if (!isBarrel) {
        violations.add(
          '$path: cross-feature import must use '
          'package:disastron/features/$targetFeature/$targetFeature.dart '
          '(got $import)',
        );
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Feature import violations (${violations.length}):');
    for (final String v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }
  stdout.writeln('check_feature_imports: OK');
}

String? _featureFromPath(String path) {
  const String prefix = 'lib/features/';
  if (!path.startsWith(prefix)) {
    return null;
  }
  final String rest = path.substring(prefix.length);
  final int slash = rest.indexOf('/');
  if (slash < 0) {
    return null;
  }
  return rest.substring(0, slash);
}

String? _packageImport(String line) {
  final String trimmed = line.trim();
  if (!trimmed.startsWith('import ')) {
    return null;
  }
  final int q1 = trimmed.indexOf("'");
  final int q2 = trimmed.lastIndexOf("'");
  if (q1 < 0 || q2 <= q1) {
    final int d1 = trimmed.indexOf('"');
    final int d2 = trimmed.lastIndexOf('"');
    if (d1 < 0 || d2 <= d1) {
      return null;
    }
    return trimmed.substring(d1 + 1, d2);
  }
  return trimmed.substring(q1 + 1, q2);
}
