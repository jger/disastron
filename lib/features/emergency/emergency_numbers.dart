import 'dart:convert';

import 'package:disastron/core/assets/bundled_asset_io.dart';

class EmergencyNumberEntry {
  const EmergencyNumberEntry({required this.label, required this.number});

  factory EmergencyNumberEntry.fromJson(Map<String, dynamic> json) {
    return EmergencyNumberEntry(
      label: json['label'] as String,
      number: json['number'] as String,
    );
  }

  final String label;
  final String number;
}

/// Offline bundled emergency numbers keyed by ISO 3166-1 alpha-2 country code.
class EmergencyNumbersPack {
  EmergencyNumbersPack._(this._byCountry);

  final Map<String, List<EmergencyNumberEntry>> _byCountry;

  List<EmergencyNumberEntry> forCountry(String? isoAlpha2) {
    if (isoAlpha2 != null && isoAlpha2.length == 2) {
      final String key = isoAlpha2.toUpperCase();
      final List<EmergencyNumberEntry>? hit = _byCountry[key];
      if (hit != null && hit.isNotEmpty) {
        return hit;
      }
    }
    return _byCountry['default'] ?? <EmergencyNumberEntry>[];
  }

  static Future<EmergencyNumbersPack> loadBundled() async {
    final String raw =
        await loadBundledAssetString('assets/data/emergency_numbers.json');
    final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, List<EmergencyNumberEntry>> out =
        <String, List<EmergencyNumberEntry>>{};
    map.forEach((String k, dynamic v) {
      final List<dynamic> list = v as List<dynamic>;
      out[k] = list
          .map(
            (dynamic e) =>
                EmergencyNumberEntry.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    });
    return EmergencyNumbersPack._(out);
  }
}
