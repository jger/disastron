import 'dart:js_interop';

@JS('flutterGemmaOPFS')
extension type _OpfsHelper._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> isModelCached(JSString filename);
}

@JS('flutterGemmaOPFS')
external _OpfsHelper get _opfs;

Future<bool> isWebOpfsModelCached(String filename) async {
  try {
    return (await _opfs.isModelCached(filename.toJS).toDart).toDart;
  } catch (_) {
    return false;
  }
}
