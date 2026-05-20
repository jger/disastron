import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Removes TFLite XNNPACK mmap weight cache files under the app temp/cache dir.
/// Partial or corrupted caches can trigger "cannot append buffer to cache file" / SIGABRT.
Future<void> clearTfliteXnnpackWeightCaches() async {
  if (kIsWeb) return;
  final Directory dir = await getTemporaryDirectory();
  await for (final FileSystemEntity entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    final String name = entity.uri.pathSegments.last;
    if (!name.endsWith('.xnnpack_cache')) continue;
    try {
      await entity.delete();
    } catch (_) {}
  }
}
