import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _kLoraRegistryJsonKey = 'disastron_lora_registry_v1';

/// One LoRA adapter entry bound to a specific base model registry entry.
class InstalledLoraEntry {
  const InstalledLoraEntry({
    required this.id,
    required this.modelEntryId,
    required this.sourceUrlOrPath,
    required this.displayLabel,
    this.importedFromPicker = false,
  });

  factory InstalledLoraEntry.fromJson(Map<String, dynamic> j) {
    return InstalledLoraEntry(
      id: j['id']! as String,
      modelEntryId: j['modelEntryId']! as String,
      sourceUrlOrPath: j['sourceUrlOrPath']! as String,
      displayLabel: j['displayLabel']! as String,
      importedFromPicker: j['importedFromPicker'] as bool? ?? false,
    );
  }

  /// Unique LoRA entry id (e.g. 'lora:hash').
  final String id;

  /// The InstalledModelEntry ID this LoRA belongs to.
  final String modelEntryId;

  /// Original download URL or local file path.
  final String sourceUrlOrPath;

  /// Human-readable name shown in the UI.
  final String displayLabel;

  /// True when the file was imported via the file picker (path is absolute).
  final bool importedFromPicker;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'modelEntryId': modelEntryId,
    'sourceUrlOrPath': sourceUrlOrPath,
    'displayLabel': displayLabel,
    'importedFromPicker': importedFromPicker,
  };
}

/// Full on-device LoRA library: entries + one active LoRA per base model.
class LoraRegistrySnapshot {
  const LoraRegistrySnapshot({
    required this.entries,
    Map<String, String>? activeLoraIdPerModel,
  }) : activeLoraIdPerModel = activeLoraIdPerModel ?? const <String, String>{};

  factory LoraRegistrySnapshot.fromJson(Map<String, dynamic> j) {
    final List<dynamic> raw = j['entries'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic> activeRaw =
        j['activeLoraIdPerModel'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    return LoraRegistrySnapshot(
      entries: raw
          .map(
            (dynamic x) =>
                InstalledLoraEntry.fromJson(x as Map<String, dynamic>),
          )
          .toList(),
      activeLoraIdPerModel: activeRaw.map(
        (String k, dynamic v) => MapEntry<String, String>(k, v as String),
      ),
    );
  }

  final List<InstalledLoraEntry> entries;

  /// Keys: modelEntryId — Values: loraEntryId that is active.
  final Map<String, String> activeLoraIdPerModel;

  /// All LoRA entries for a specific base model.
  List<InstalledLoraEntry> entriesForModel(String modelEntryId) => entries
      .where((InstalledLoraEntry e) => e.modelEntryId == modelEntryId)
      .toList();

  /// Active LoRA entry for a model, or null.
  InstalledLoraEntry? activeLoraForModel(String modelEntryId) {
    final String? activeId = activeLoraIdPerModel[modelEntryId];
    if (activeId == null) return null;
    for (final InstalledLoraEntry e in entries) {
      if (e.id == activeId) return e;
    }
    return null;
  }

  /// Lookup by entry id.
  InstalledLoraEntry? entryById(String id) {
    for (final InstalledLoraEntry e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': 1,
    'entries': entries.map((InstalledLoraEntry e) => e.toJson()).toList(),
    'activeLoraIdPerModel': activeLoraIdPerModel,
  };
}

/// SharedPreferences-backed persistence for LoRA entries.
class LoraRegistryStore {
  Future<LoraRegistrySnapshot> readSnapshot() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_kLoraRegistryJsonKey);
    if (raw == null || raw.isEmpty) {
      return const LoraRegistrySnapshot(entries: <InstalledLoraEntry>[]);
    }
    try {
      final Map<String, dynamic> j = jsonDecode(raw) as Map<String, dynamic>;
      return LoraRegistrySnapshot.fromJson(j);
    } on Object {
      return const LoraRegistrySnapshot(entries: <InstalledLoraEntry>[]);
    }
  }

  Future<void> writeSnapshot(LoraRegistrySnapshot snapshot) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLoraRegistryJsonKey, jsonEncode(snapshot.toJson()));
  }
}
