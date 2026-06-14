import 'dart:js_interop';

@JS('storageRequestPersistent')
external JSPromise<JSBoolean> _storageRequestPersistentJS();

/// Calls navigator.storage.persist() via cache_api.js to prevent OPFS eviction
/// under storage pressure or Safari's 7-day ITP clearance for non-installed PWAs.
Future<void> requestWebStoragePersistence() async {
  try {
    await _storageRequestPersistentJS().toDart;
  } catch (_) {}
}
