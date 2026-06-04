// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

/// Translation keys for geolocation errors shown on the dashboard.
abstract final class DashboardLocationErrors {
  DashboardLocationErrors._();

  static const String permissionDenied = 'location_permission_denied';
  static const String servicesDisabled = 'location_services_disabled';
  static const String unavailableFallback = 'location_unavailable';
}
