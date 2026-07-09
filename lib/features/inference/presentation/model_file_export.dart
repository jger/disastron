import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

enum ModelExportResultKind { success, cancelled, failure, unsupported }

class ModelExportResult {
  const ModelExportResult._({required this.kind, this.savedPath, this.message});

  factory ModelExportResult.cancelled() =>
      const ModelExportResult._(kind: ModelExportResultKind.cancelled);

  factory ModelExportResult.success(String path) =>
      ModelExportResult._(kind: ModelExportResultKind.success, savedPath: path);

  factory ModelExportResult.failure(String message) => ModelExportResult._(
    kind: ModelExportResultKind.failure,
    message: message,
  );

  factory ModelExportResult.unsupported() => const ModelExportResult._(
    kind: ModelExportResultKind.unsupported,
    message: 'Not supported on this platform.',
  );

  final ModelExportResultKind kind;
  final String? savedPath;
  final String? message;
}

Future<ModelExportResult> exportModelFileToUserChosenLocation({
  required String absoluteSourcePath,
}) async {
  if (kIsWeb) {
    return ModelExportResult.unsupported();
  }
  final File f = File(absoluteSourcePath);
  if (!f.existsSync()) {
    return ModelExportResult.failure('Model file not found.');
  }
  final String name = p.basename(absoluteSourcePath);
  final Uint8List bytes = await f.readAsBytes();
  try {
    final String? out = await FilePicker.saveFile(
      dialogTitle: 'Save a copy (e.g. Downloads)',
      fileName: name,
      bytes: bytes,
    );
    if (out == null || out.isEmpty) {
      return ModelExportResult.cancelled();
    }
    return ModelExportResult.success(out);
  } on Object catch (e) {
    return ModelExportResult.failure(e.toString());
  }
}
