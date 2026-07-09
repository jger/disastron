import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kUrl = 'disastron_model_url';
const String _kModelType = 'disastron_model_type';
const String _kFileType = 'disastron_model_file_type';

/// Last successful inference install (network URL or absolute file path).
class ModelInstallRecord {
  const ModelInstallRecord({
    required this.urlOrPath,
    required this.modelType,
    required this.fileType,
  });

  final String urlOrPath;
  final ModelType modelType;
  final ModelFileType fileType;
}

class ModelInstallPrefs {
  Future<void> save({
    required String urlOrPath,
    required ModelType modelType,
    required ModelFileType fileType,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUrl, urlOrPath);
    await prefs.setString(_kModelType, modelType.name);
    await prefs.setString(_kFileType, fileType.name);
  }

  Future<ModelInstallRecord?> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? urlOrPath = prefs.getString(_kUrl);
    final String? modelTypeName = prefs.getString(_kModelType);
    final String? fileTypeName = prefs.getString(_kFileType);
    if (urlOrPath == null || modelTypeName == null || fileTypeName == null) {
      return null;
    }
    try {
      final ModelType modelType = ModelType.values.firstWhere(
        (ModelType e) => e.name == modelTypeName,
      );
      final ModelFileType fileType = ModelFileType.values.firstWhere(
        (ModelFileType e) => e.name == fileTypeName,
      );
      return ModelInstallRecord(
        urlOrPath: urlOrPath,
        modelType: modelType,
        fileType: fileType,
      );
    } on Object {
      return null;
    }
  }
}
