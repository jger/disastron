/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

/// SSOT for geolocation error strings shown on the dashboard (device + weather).
abstract final class DashboardLocationErrors {
  DashboardLocationErrors._();

  static const String permissionDenied = 'Location permission denied';
  static const String servicesDisabled = 'Location services disabled';
  static const String unavailableFallback =
      'Location unavailable — enable GPS & permission.';
}
