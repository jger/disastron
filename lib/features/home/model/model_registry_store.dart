import 'dart:convert';

import 'package:disastron/features/home/model/model_install_prefs.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRegistryJsonKey = 'disastron_model_registry_v2';

/// One row in the on-device model library (metadata only; files managed by flutter_gemma).
class InstalledModelEntry {
  const InstalledModelEntry({
    required this.id,
    required this.sourceUrlOrPath,
    required this.modelType,
    required this.fileType,
    required this.displayTitle,
    this.presetId,
    this.importedFromPicker = false,
  });

  final String id;
  final String sourceUrlOrPath;
  final ModelType modelType;
  final ModelFileType fileType;
  final String displayTitle;
  final String? presetId;
  final bool importedFromPicker;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sourceUrlOrPath': sourceUrlOrPath,
        'modelType': modelType.name,
        'fileType': fileType.name,
        'displayTitle': displayTitle,
        if (presetId != null) 'presetId': presetId,
        'importedFromPicker': importedFromPicker,
      };

  factory InstalledModelEntry.fromJson(Map<String, dynamic> j) {
    return InstalledModelEntry(
      id: j['id']! as String,
      sourceUrlOrPath: j['sourceUrlOrPath']! as String,
      modelType: ModelType.values
          .firstWhere((ModelType e) => e.name == j['modelType']! as String),
      fileType: ModelFileType.values
          .firstWhere((ModelFileType e) => e.name == j['fileType']! as String),
      displayTitle: j['displayTitle']! as String,
      presetId: j['presetId'] as String?,
      importedFromPicker: j['importedFromPicker'] as bool? ?? false,
    );
  }
}

class ModelRegistrySnapshot {
  const ModelRegistrySnapshot({
    required this.entries,
    this.activeEntryId,
  });

  final List<InstalledModelEntry> entries;
  final String? activeEntryId;

  InstalledModelEntry? entryById(String id) {
    for (final InstalledModelEntry e in entries) {
      if (e.id == id) {
        return e;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 1,
        'entries': entries.map((InstalledModelEntry e) => e.toJson()).toList(),
        if (activeEntryId != null) 'activeEntryId': activeEntryId,
      };

  factory ModelRegistrySnapshot.fromJson(Map<String, dynamic> j) {
    final List<dynamic> raw = j['entries'] as List<dynamic>? ?? <dynamic>[];
    return ModelRegistrySnapshot(
      entries: raw
          .map(
            (dynamic x) =>
                InstalledModelEntry.fromJson(x as Map<String, dynamic>),
          )
          .toList(),
      activeEntryId: j['activeEntryId'] as String?,
    );
  }
}

class ModelRegistryStore {
  Future<ModelRegistrySnapshot> readSnapshot() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_kRegistryJsonKey);
    if (raw == null || raw.isEmpty) {
      return const ModelRegistrySnapshot(entries: <InstalledModelEntry>[]);
    }
    try {
      final Map<String, dynamic> j =
          jsonDecode(raw) as Map<String, dynamic>;
      return ModelRegistrySnapshot.fromJson(j);
    } on Object {
      return const ModelRegistrySnapshot(entries: <InstalledModelEntry>[]);
    }
  }

  Future<void> writeSnapshot(ModelRegistrySnapshot snapshot) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRegistryJsonKey,
      jsonEncode(snapshot.toJson()),
    );
  }

  /// One-time migration from [ModelInstallPrefs] single-record storage.
  Future<void> migrateFromLegacyIfNeeded() async {
    ModelRegistrySnapshot current = await readSnapshot();
    if (current.entries.isNotEmpty) {
      return;
    }
    final ModelInstallRecord? legacy =
        await ModelInstallPrefs().read();
    if (legacy == null) {
      return;
    }
    final String id = 'legacy:${legacy.urlOrPath.hashCode}';
    final String title = _titleFromLegacySource(legacy.urlOrPath);
    current = ModelRegistrySnapshot(
      entries: <InstalledModelEntry>[
        InstalledModelEntry(
          id: id,
          sourceUrlOrPath: legacy.urlOrPath,
          modelType: legacy.modelType,
          fileType: legacy.fileType,
          displayTitle: title,
          importedFromPicker: !legacy.urlOrPath.contains('://'),
        ),
      ],
      activeEntryId: id,
    );
    await writeSnapshot(current);
  }

  String _titleFromLegacySource(String urlOrPath) {
    final Uri uri =
        urlOrPath.contains('://') ? Uri.parse(urlOrPath) : Uri.file(urlOrPath);
    if (uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return urlOrPath;
  }
}
