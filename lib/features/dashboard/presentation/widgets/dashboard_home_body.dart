// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/app/locale_provider.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_device_provider.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_weather_provider.dart';
import 'package:disastron/features/dashboard/presentation/widgets/dashboard_banners.dart';
import 'package:disastron/features/dashboard/presentation/widgets/dashboard_status_card.dart';
import 'package:disastron/features/dashboard/presentation/widgets/dashboard_tool_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Main dashboard scrollable body: status, quick actions.
class DashboardHomeBody extends ConsumerWidget {
  const DashboardHomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when locale changes (IndexedStack + const children can skip subtree otherwise).
    ref.watch(
      appLocaleProvider.select(
        (AsyncValue<AppLocaleState> a) => a.maybeWhen(
          data: (AppLocaleState s) => s.localeCode,
          orElse: () => '',
        ),
      ),
    );
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(dashboardLocationProvider)
          ..invalidate(dashboardBatteryProvider)
          ..invalidate(dashboardWeatherProvider);
      },
      child: const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DashboardStatusCard(),
            SizedBox(height: 16),
            DashboardNoOfflineModelBanner(),
            DashboardNoOfflineWikiBanner(),
            SizedBox(height: 16),
            DashboardHcBatteryTipBanner(),
            SizedBox(height: 16),
            DashboardToolGrid(),
          ],
        ),
      ),
    );
  }
}
