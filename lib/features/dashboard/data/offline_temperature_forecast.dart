import 'dart:math' as math;

import 'package:disastron/core/assets/bundled_asset_io.dart';
import 'package:flutter/foundation.dart';

@immutable
class ClimateStation {
  const ClimateStation({
    required this.latitudeDeg,
    required this.longitudeDeg,
    required this.monthly,
  });

  factory ClimateStation.fromJson(Map<String, dynamic> json) {
    final List<dynamic> m = json['m'] as List<dynamic>? ?? const <dynamic>[];
    final List<List<double>> rows = <List<double>>[];
    for (final dynamic row in m) {
      final List<dynamic> pair = row as List<dynamic>;
      rows.add(<double>[
        (pair[0] as num).toDouble(),
        (pair[1] as num).toDouble(),
      ]);
    }
    if (rows.length != 12) {
      throw FormatException(
        'climate station needs 12 monthly rows, got ${rows.length}',
      );
    }
    return ClimateStation(
      latitudeDeg: (json['lat'] as num).toDouble(),
      longitudeDeg: (json['lon'] as num).toDouble(),
      monthly: rows,
    );
  }

  final double latitudeDeg;
  final double longitudeDeg;

  /// Index 0 = January … 11 = December; each pair is [dayAvgC, nightAvgC].
  final List<List<double>> monthly;
}

/// Bundled coarse monthly climate normals (day vs night average °C).
@immutable
class ClimateNormalsPack {
  const ClimateNormalsPack({
    required this.version,
    required this.stations,
    this.note,
  });

  factory ClimateNormalsPack.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        json['stations'] as List<dynamic>? ?? const <dynamic>[];
    return ClimateNormalsPack(
      version: (json['v'] as num?)?.toInt() ?? 1,
      note: json['note'] as String?,
      stations: raw
          .map(
            (dynamic e) => ClimateStation.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final int version;
  final String? note;
  final List<ClimateStation> stations;
}

Future<ClimateNormalsPack> loadBundledClimateNormalsPack() {
  return decodeBundledJsonObject(
    'assets/data/climate_normals.json',
    ClimateNormalsPack.fromJson,
  );
}

@immutable
class OfflineTemperatureForecast {
  const OfflineTemperatureForecast({
    required this.month1to12,
    required this.dayAvgC,
    required this.nightAvgC,
    required this.methodLabel,
    required this.nearestStationKm,
  });

  final int month1to12;
  final double dayAvgC;
  final double nightAvgC;
  final String methodLabel;
  final double nearestStationKm;
}

const String _kForecastMethod = 'offline_climate_normals_idw';

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const double earthKm = 6371;
  final double p1 = lat1 * math.pi / 180;
  final double p2 = lat2 * math.pi / 180;
  final double dp = (lat2 - lat1) * math.pi / 180;
  final double dl = (lon2 - lon1) * math.pi / 180;
  final double a =
      math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthKm * c;
}

/// Inverse-distance weighted blend of the nearest stations for [month1to12].
OfflineTemperatureForecast forecastOfflineTemperature({
  required ClimateNormalsPack pack,
  required double latitudeDeg,
  required double longitudeDeg,
  required int month1to12,
  int neighborCount = 4,
}) {
  if (month1to12 < 1 || month1to12 > 12) {
    throw ArgumentError.value(month1to12, 'month1to12', 'must be 1..12');
  }
  if (pack.stations.isEmpty) {
    throw StateError('climate normals pack has no stations');
  }

  final int mi = month1to12 - 1;

  final List<({ClimateStation st, double d})> ranked =
      <({ClimateStation st, double d})>[];
  for (final ClimateStation st in pack.stations) {
    final double d = _haversineKm(
      latitudeDeg,
      longitudeDeg,
      st.latitudeDeg,
      st.longitudeDeg,
    );
    ranked.add((st: st, d: d));
  }
  ranked.sort((a, b) => a.d.compareTo(b.d));

  final double nearestKm = ranked.first.d;

  final int k = math.min(neighborCount, ranked.length);
  double wSum = 0;
  double daySum = 0;
  double nightSum = 0;
  const double epsKm = 25;
  for (int i = 0; i < k; i++) {
    final ClimateStation st = ranked[i].st;
    final double d = ranked[i].d;
    final double w = 1 / (d * d + epsKm * epsKm);
    daySum += w * st.monthly[mi][0];
    nightSum += w * st.monthly[mi][1];
    wSum += w;
  }

  return OfflineTemperatureForecast(
    month1to12: month1to12,
    dayAvgC: daySum / wSum,
    nightAvgC: nightSum / wSum,
    methodLabel: _kForecastMethod,
    nearestStationKm: nearestKm,
  );
}
