// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:path/path.dart' as p;

/// Last path segment from a URL or filesystem path.
String basenameFromStored(String urlOrPath) {
  final Uri uri = urlOrPath.contains('://')
      ? Uri.parse(urlOrPath)
      : Uri.file(urlOrPath);
  if (uri.pathSegments.isEmpty) {
    return urlOrPath;
  }
  return uri.pathSegments.last;
}

/// Extracts and validates a single safe filename from a stored URL or path,
/// returning `null` if invalid.
///
/// Rejects empty names, dot segments (`.` / `..`), null bytes, control
/// characters, path separators (`/` or `\`, including those produced by
/// percent-decoding URL segments such as `%2E%2E%2F`), colons, and absolute
/// paths.
String? trySafeFilenameFromStored(String urlOrPath) {
  final Uri? uri = urlOrPath.contains('://')
      ? Uri.tryParse(urlOrPath)
      : Uri.file(urlOrPath);
  if (uri == null || uri.pathSegments.isEmpty) {
    return null;
  }
  final String candidate = uri.pathSegments.last;
  if (!_isSafeSingleFilename(candidate)) {
    return null;
  }
  return candidate;
}

/// Extracts and validates a single safe filename from a stored URL or path.
///
/// Throws a [FormatException] if [urlOrPath] does not yield a safe single
/// filename.
String safeFilenameFromStored(String urlOrPath) {
  final String? filename = trySafeFilenameFromStored(urlOrPath);
  if (filename == null) {
    throw FormatException(
      'Unsafe or invalid filename derived from URL or path',
      urlOrPath,
    );
  }
  return filename;
}

bool _isSafeSingleFilename(String name) {
  if (name.isEmpty || name == '.' || name == '..') {
    return false;
  }
  if (name.contains('/') ||
      name.contains(r'\') ||
      name.contains(':') ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(name)) {
    return false;
  }
  if (p.isAbsolute(name) || p.basename(name) != name) {
    return false;
  }
  return true;
}

/// Resolves [urlOrPath] to a direct child file inside [baseDirectory], or
/// returns `null` if the derived filename is unsafe or would escape
/// [baseDirectory].
String? tryResolveConfinedFilePath(String baseDirectory, String urlOrPath) {
  final String? filename = trySafeFilenameFromStored(urlOrPath);
  if (filename == null) {
    return null;
  }
  final String normalizedBase = p.normalize(p.absolute(baseDirectory));
  final String resolved = p.normalize(p.join(normalizedBase, filename));
  if (!p.isWithin(normalizedBase, resolved) ||
      p.dirname(resolved) != normalizedBase) {
    return null;
  }
  return resolved;
}

/// Resolves [urlOrPath] to a direct child file inside [baseDirectory].
///
/// Throws a [FormatException] if the derived filename is unsafe or if the
/// normalized path would escape [baseDirectory].
String resolveConfinedFilePath(String baseDirectory, String urlOrPath) {
  final String? resolved = tryResolveConfinedFilePath(baseDirectory, urlOrPath);
  if (resolved == null) {
    throw FormatException(
      'Resolved path escapes target directory or has an invalid filename',
      urlOrPath,
    );
  }
  return resolved;
}
