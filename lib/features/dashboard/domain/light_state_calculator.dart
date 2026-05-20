import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Sunrise/sunset + day/night classification from geolocation and local time.
/// Uses NOAA-style approximate solar equations (no network).
@immutable
class LightStateResult {
  const LightStateResult({
    required this.nowLocal,
    required this.latitudeDeg,
    required this.longitudeDeg,
    required this.sunriseLocal,
    required this.sunsetLocal,
    required this.isPolarNight,
    required this.isPolarDay,
    required this.isDay,
  });

  final DateTime nowLocal;
  final double latitudeDeg;
  final double longitudeDeg;
  final DateTime? sunriseLocal;
  final DateTime? sunsetLocal;
  final bool isPolarNight;
  final bool isPolarDay;

  /// True when sun is above horizon (official sunrise/set), excluding polar edge cases.
  final bool isDay;
}

/// Computes solar rise/set for the calendar day of [nowLocal] in that timezone.
LightStateResult computeLightState({
  required DateTime nowLocal,
  required double latitudeDeg,
  required double longitudeDeg,
}) {
  final DateTime localNoon =
      DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 12);

  final double lon = longitudeDeg;
  final double lat = latitudeDeg;
  final double latRad = lat * math.pi / 180;

  // Fractional year (γ) using UTC calendar instant of local solar noon (NOAA-style).
  final DateTime utcNoon = localNoon.toUtc();
  final int dayOfYearUtc =
      utcNoon.difference(DateTime.utc(utcNoon.year)).inDays + 1;
  final double utcHour =
      utcNoon.hour + utcNoon.minute / 60 + utcNoon.second / 3600;
  final double gamma =
      2 * math.pi / 365 * (dayOfYearUtc - 1 + (utcHour - 12) / 24);

  final double eqtime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(gamma) -
          0.032077 * math.sin(gamma) -
          0.014615 * math.cos(2 * gamma) -
          0.040849 * math.sin(2 * gamma));

  final double declRad = 0.006918 -
      0.399912 * math.cos(gamma) +
      0.070257 * math.sin(gamma) -
      0.006758 * math.cos(2 * gamma) +
      0.000907 * math.sin(2 * gamma) -
      0.002697 * math.cos(3 * gamma) +
      0.001480 * math.sin(3 * gamma);

  const double zenithOfficialDeg = 90.83333333333333;
  final double cosZen =
      math.cos(zenithOfficialDeg * math.pi / 180); // ≈ -0.01454 with refraction

  final double cosH = (cosZen - math.sin(latRad) * math.sin(declRad)) /
      (math.cos(latRad) * math.cos(declRad));

  if (cosH > 1) {
    return LightStateResult(
      nowLocal: nowLocal,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      sunriseLocal: null,
      sunsetLocal: null,
      isPolarNight: true,
      isPolarDay: false,
      isDay: false,
    );
  }
  if (cosH < -1) {
    return LightStateResult(
      nowLocal: nowLocal,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      sunriseLocal: null,
      sunsetLocal: null,
      isPolarNight: false,
      isPolarDay: true,
      isDay: true,
    );
  }

  final double haDeg = math.acos(cosH) * 180 / math.pi;

  final double sunriseUtcMin = 720 - 4 * (lon + haDeg) - eqtime;
  final double sunsetUtcMin = 720 - 4 * (lon - haDeg) - eqtime;

  final DateTime utcMidnight =
      DateTime.utc(utcNoon.year, utcNoon.month, utcNoon.day);
  final DateTime sunriseUtc = utcMidnight.add(
    Duration(milliseconds: (sunriseUtcMin * 60 * 1000).round()),
  );
  final DateTime sunsetUtc = utcMidnight.add(
    Duration(milliseconds: (sunsetUtcMin * 60 * 1000).round()),
  );
  final DateTime rise = sunriseUtc.toLocal();
  final DateTime set = sunsetUtc.toLocal();

  final bool isDay = !nowLocal.isBefore(rise) && nowLocal.isBefore(set);

  return LightStateResult(
    nowLocal: nowLocal,
    latitudeDeg: latitudeDeg,
    longitudeDeg: longitudeDeg,
    sunriseLocal: rise,
    sunsetLocal: set,
    isPolarNight: false,
    isPolarDay: false,
    isDay: isDay,
  );
}
