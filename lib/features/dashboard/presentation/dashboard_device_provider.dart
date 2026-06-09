// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'dart:async';

import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:disastron/features/dashboard/domain/location_error_messages.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_device_provider.g.dart';

/// Snapshot for location status.
@immutable
class DashboardLocationSnapshot {
  const DashboardLocationSnapshot({
    this.latitude,
    this.longitude,
    this.isoCountryCode,
    this.locality,
    this.locationError,
  });

  final double? latitude;
  final double? longitude;
  final String? isoCountryCode;
  final String? locality;
  final String? locationError;

  bool get hasFix => latitude != null && longitude != null;
}

/// Snapshot for battery status and sampling time.
@immutable
class DashboardBatterySnapshot {
  const DashboardBatterySnapshot({
    required this.sampledAt,
    this.batteryPercent,
    this.batteryState,
  });

  final DateTime sampledAt;
  final int? batteryPercent;
  final BatteryState? batteryState;
}

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
Future<DashboardLocationSnapshot> dashboardLocation(Ref ref) async {
  double? lat;
  double? lon;
  String? iso;
  String? locality;
  String? locErr;

  try {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      locErr = DashboardLocationErrors.permissionDenied;
    } else {
      final bool serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        locErr = DashboardLocationErrors.servicesDisabled;
      } else {
        final Position pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 5),
              ),
            );
        lat = pos.latitude;
        lon = pos.longitude;

        try {
          final List<Placemark> marks = await placemarkFromCoordinates(
            lat,
            lon,
          ).timeout(const Duration(seconds: 2));
          if (marks.isNotEmpty) {
            final Placemark p = marks.first;
            iso = p.isoCountryCode;
            locality =
                p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
          }
        } on Object {
          // Ignore geocoding failure offline so GPS coordinates still work.
        }
      }
    }
  } on Object {
    locErr = DashboardLocationErrors.unavailableFallback;
  }

  return DashboardLocationSnapshot(
    latitude: lat,
    longitude: lon,
    isoCountryCode: iso,
    locality: locality,
    locationError: locErr,
  );
}

@riverpod
Future<DashboardBatterySnapshot> dashboardBattery(Ref ref) async {
  final Battery battery = Battery();

  int? pct;
  BatteryState? batState;
  try {
    pct = await battery.batteryLevel;
    batState = await battery.batteryState;
  } on Object {
    // ignore
  }

  // Set up timer to refresh every minute
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    final timer = Timer(const Duration(minutes: 1), () {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }
  return DashboardBatterySnapshot(
    sampledAt: DateTime.now(),
    batteryPercent: pct,
    batteryState: batState,
  );
}

@riverpod
Future<DashboardDeviceSnapshot> dashboardDevice(Ref ref) async {
  final battery = await ref.watch(dashboardBatteryProvider.future);
  final location = await ref.watch(dashboardLocationProvider.future);

  return DashboardDeviceSnapshot(
    sampledAt: battery.sampledAt,
    batteryPercent: battery.batteryPercent,
    batteryState: battery.batteryState,
    latitude: location.latitude,
    longitude: location.longitude,
    isoCountryCode: location.isoCountryCode,
    locality: location.locality,
    locationError: location.locationError,
  );
}
