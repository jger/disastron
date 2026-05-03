import 'package:disastron/features/home/dashboard/dashboard_device_provider.dart';
import 'package:disastron/features/home/dashboard/light_state_calculator.dart';
import 'package:disastron/features/home/dashboard/offline_temperature_forecast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<ClimateNormalsPack>? _climateNormalsPackMemo;

Future<ClimateNormalsPack> _loadClimateNormalsPackOnce() {
  return _climateNormalsPackMemo ??= loadBundledClimateNormalsPack();
}

@immutable
class DashboardWeatherSnapshot {
  const DashboardWeatherSnapshot({
    required this.sampledAtLocal,
    this.latitude,
    this.longitude,
    this.locationError,
    this.light,
    this.forecast,
    this.forecastError,
  });

  final DateTime sampledAtLocal;
  final double? latitude;
  final double? longitude;

  /// Geolocation permission / services / fix errors from device snapshot.
  final String? locationError;

  final LightStateResult? light;
  final OfflineTemperatureForecast? forecast;

  /// Dataset parse / IO failures only (GPS present).
  final String? forecastError;

  bool get hasFix => latitude != null && longitude != null;
}

final FutureProvider<DashboardWeatherSnapshot> dashboardWeatherProvider =
    FutureProvider.autoDispose<DashboardWeatherSnapshot>((Ref ref) async {
  final DashboardDeviceSnapshot device =
      await ref.watch(dashboardDeviceProvider.future);
  final DateTime nowLocal = DateTime.now();

  if (!device.hasFix) {
    return DashboardWeatherSnapshot(
      sampledAtLocal: nowLocal,
      latitude: device.latitude,
      longitude: device.longitude,
      locationError:
          device.locationError ?? 'Location unavailable — enable GPS & permission.',
    );
  }

  final double lat = device.latitude!;
  final double lon = device.longitude!;

  final LightStateResult light = computeLightState(
    nowLocal: nowLocal,
    latitudeDeg: lat,
    longitudeDeg: lon,
  );

  try {
    final ClimateNormalsPack pack = await _loadClimateNormalsPackOnce();
    final OfflineTemperatureForecast forecast = forecastOfflineTemperature(
      pack: pack,
      latitudeDeg: lat,
      longitudeDeg: lon,
      month1to12: nowLocal.month,
    );
    return DashboardWeatherSnapshot(
      sampledAtLocal: nowLocal,
      latitude: lat,
      longitude: lon,
      light: light,
      forecast: forecast,
    );
  } on Object catch (e) {
    return DashboardWeatherSnapshot(
      sampledAtLocal: nowLocal,
      latitude: lat,
      longitude: lon,
      light: light,
      forecastError: 'Climate data error: $e',
    );
  }
});
