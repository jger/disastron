import 'package:disastron/features/chat/presentation/service/gemma_service.dart';
import 'package:disastron/features/dashboard/data/offline_temperature_forecast.dart';
import 'package:disastron/features/dashboard/domain/light_state_calculator.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_device_provider.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_weather_provider.dart';

/// Builds the variable part of the chat system instruction from dashboard data.
/// Field names stay stable so offline prompts stay reproducible across locales.
String formatChatDashboardSituation({
  required DashboardDeviceSnapshot device,
  required DashboardWeatherSnapshot weather,
}) {
  final StringBuffer b = StringBuffer()
    ..writeln(
      'time_device_sample_utc: ${device.sampledAt.toUtc().toIso8601String()}',
    )
    ..writeln(
      'time_weather_sample_local: ${weather.sampledAtLocal.toIso8601String()}',
    );

  if (device.batteryPercent != null) {
    b.writeln('battery_percent: ${device.batteryPercent}');
  } else {
    b.writeln('battery_percent: unknown');
  }
  if (device.batteryState != null) {
    b.writeln('battery_state: ${device.batteryState!.name}');
  } else {
    b.writeln('battery_state: unknown');
  }

  if (device.hasFix) {
    b
      ..writeln('gps_latitude: ${device.latitude}')
      ..writeln('gps_longitude: ${device.longitude}');
  } else {
    b
      ..writeln('gps_latitude: unknown')
      ..writeln('gps_longitude: unknown');
  }

  b
    ..writeln('place_locality: ${_orUnknown(device.locality)}')
    ..writeln('country_iso: ${_orUnknown(device.isoCountryCode)}');

  final String? locErr = device.locationError ?? weather.locationError;
  if (locErr != null && locErr.isNotEmpty) {
    b.writeln('location_error: $locErr');
  }

  final LightStateResult? light = weather.light;
  if (light != null) {
    b
      ..writeln('solar_is_day: ${light.isDay}')
      ..writeln('solar_is_polar_day: ${light.isPolarDay}')
      ..writeln('solar_is_polar_night: ${light.isPolarNight}');
    final DateTime? sr = light.sunriseLocal;
    final DateTime? ss = light.sunsetLocal;
    if (sr != null) {
      b.writeln('sunrise_local: ${sr.toIso8601String()}');
    }
    if (ss != null) {
      b.writeln('sunset_local: ${ss.toIso8601String()}');
    }
  } else if (weather.hasFix) {
    b.writeln('solar: unknown');
  } else {
    b.writeln('solar: unavailable_no_gps_fix');
  }

  final OfflineTemperatureForecast? fc = weather.forecast;
  if (fc != null) {
    b
      ..writeln('climate_normals_month: ${fc.month1to12}')
      ..writeln('climate_normals_day_avg_c: ${fc.dayAvgC.toStringAsFixed(1)}')
      ..writeln(
        'climate_normals_night_avg_c: ${fc.nightAvgC.toStringAsFixed(1)}',
      )
      ..writeln('climate_normals_method: ${fc.methodLabel}')
      ..writeln(
        'climate_nearest_station_km: ${fc.nearestStationKm.toStringAsFixed(0)}',
      );
  } else if (weather.forecastError != null &&
      weather.forecastError!.isNotEmpty) {
    b.writeln('climate_normals_error: ${weather.forecastError}');
  } else {
    b.writeln('climate_normals: unavailable');
  }

  return b.toString().trimRight();
}

String formatChatDashboardSituationError(Object error) {
  return 'context_error: $error';
}

/// Full system instruction: static disaster prompt + structured device context.
String composeDisasterSystemInstruction(String situationBlock) {
  final String trimmed = situationBlock.trim();
  final String block = trimmed.isEmpty ? 'context_error: empty' : trimmed;
  return '${kDisasterSystemInstruction.trim()}\n\n'
      '---\n'
      'Current device context (sampled when Chat was opened; offline estimates, '
      'not live weather):\n'
      '$block';
}

String _orUnknown(String? v) {
  if (v == null || v.trim().isEmpty) {
    return 'unknown';
  }
  return v.trim();
}
