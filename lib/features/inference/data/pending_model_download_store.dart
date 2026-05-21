import 'dart:convert';

import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted metadata for an in-flight network model download (resume after interrupt).
class PendingModelDownload {
  const PendingModelDownload({
    required this.url,
    required this.filename,
    required this.modelType,
    required this.fileType,
    required this.lastProgress,
    required this.updatedAt,
    this.presetId,
  });

  final String url;
  final String filename;
  final String? presetId;
  final ModelType modelType;
  final ModelFileType fileType;
  final int lastProgress;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'url': url,
        'filename': filename,
        if (presetId != null) 'presetId': presetId,
        'modelType': modelType.name,
        'fileType': fileType.name,
        'lastProgress': lastProgress,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static PendingModelDownload? fromJson(Map<String, dynamic> json) {
    final String? url = json['url'] as String?;
    final String? filename = json['filename'] as String?;
    final String? modelTypeName = json['modelType'] as String?;
    final String? fileTypeName = json['fileType'] as String?;
    final String? updatedAtRaw = json['updatedAt'] as String?;
    if (url == null ||
        url.isEmpty ||
        filename == null ||
        filename.isEmpty ||
        modelTypeName == null ||
        fileTypeName == null ||
        updatedAtRaw == null) {
      return null;
    }
    ModelType? modelType;
    for (final ModelType v in ModelType.values) {
      if (v.name == modelTypeName) {
        modelType = v;
        break;
      }
    }
    ModelFileType? fileType;
    for (final ModelFileType v in ModelFileType.values) {
      if (v.name == fileTypeName) {
        fileType = v;
        break;
      }
    }
    final DateTime? updatedAt = DateTime.tryParse(updatedAtRaw);
    if (modelType == null || fileType == null || updatedAt == null) {
      return null;
    }
    return PendingModelDownload(
      url: url,
      filename: filename,
      presetId: json['presetId'] as String?,
      modelType: modelType,
      fileType: fileType,
      lastProgress: (json['lastProgress'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAt,
    );
  }
}

/// SharedPreferences-backed store for [PendingModelDownload].
class PendingModelDownloadStore {
  PendingModelDownloadStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<PendingModelDownload?> read() async {
    final SharedPreferences prefs = await _ensurePrefs();
    final String? raw = prefs.getString(PrefsKeys.pendingModelDownload);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return PendingModelDownload.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> save(PendingModelDownload pending) async {
    final SharedPreferences prefs = await _ensurePrefs();
    await prefs.setString(
      PrefsKeys.pendingModelDownload,
      jsonEncode(pending.toJson()),
    );
  }

  Future<void> updateProgress(int progress) async {
    final PendingModelDownload? current = await read();
    if (current == null) {
      return;
    }
    await save(
      PendingModelDownload(
        url: current.url,
        filename: current.filename,
        presetId: current.presetId,
        modelType: current.modelType,
        fileType: current.fileType,
        lastProgress: progress.clamp(0, 100),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await _ensurePrefs();
    await prefs.remove(PrefsKeys.pendingModelDownload);
  }
}
