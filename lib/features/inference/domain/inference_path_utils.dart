// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

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
