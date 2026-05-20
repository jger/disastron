/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'package:battery_plus/battery_plus.dart';
import 'package:disastron/features/dashboard/domain/location_error_messages.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_device_provider.g.dart';

/// Snapshot for dashboard status tiles (battery + location + clock).
@immutable
class DashboardDeviceSnapshot {
  const DashboardDeviceSnapshot({
    required this.sampledAt,
    this.batteryPercent,
    this.batteryState,
    this.latitude,
    this.longitude,
    this.isoCountryCode,
    this.locality,
    this.locationError,
  });

  final DateTime sampledAt;
  final int? batteryPercent;
  final BatteryState? batteryState;
  final double? latitude;
  final double? longitude;
  final String? isoCountryCode;
  final String? locality;
  final String? locationError;

  bool get hasFix => latitude != null && longitude != null;
}

@riverpod
Future<DashboardDeviceSnapshot> dashboardDevice(Ref ref) async {
  final DateTime sampledAt = DateTime.now();
  final Battery battery = Battery();

  int? pct;
  BatteryState? batState;
  try {
    pct = await battery.batteryLevel;
    batState = await battery.batteryState;
  } on Object {
    // ignore
  }

  LocationPermission perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }

  double? lat;
  double? lon;
  String? iso;
  String? locality;
  String? locErr;

  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    locErr = DashboardLocationErrors.permissionDenied;
  } else {
    try {
      final bool serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        locErr = DashboardLocationErrors.servicesDisabled;
      } else {
        final Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          ),
        );
        lat = pos.latitude;
        lon = pos.longitude;
        final List<Placemark> marks = await placemarkFromCoordinates(
          lat,
          lon,
        );
        if (marks.isNotEmpty) {
          final Placemark p = marks.first;
          iso = p.isoCountryCode;
          locality =
              p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
        }
      }
    } on Object catch (e) {
      locErr = e.toString();
    }
  }

  return DashboardDeviceSnapshot(
    sampledAt: sampledAt,
    batteryPercent: pct,
    batteryState: batState,
    latitude: lat,
    longitude: lon,
    isoCountryCode: iso,
    locality: locality,
    locationError: locErr,
  );
}
