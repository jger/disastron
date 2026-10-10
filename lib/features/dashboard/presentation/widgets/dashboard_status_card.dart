// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:battery_plus/battery_plus.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_device_provider.dart';
import 'package:disastron/features/dashboard/presentation/widgets/dashboard_weather_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardStatusCard extends ConsumerWidget {
  const DashboardStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardDeviceSnapshot> async = ref.watch(
      dashboardDeviceProvider,
    );

    return async.when(
      data: (DashboardDeviceSnapshot s) =>
          _DashboardStatusExpansionTile(snapshot: s),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (Object e, StackTrace st) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Status error: $e',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardStatusExpansionTile extends StatelessWidget {
  const _DashboardStatusExpansionTile({required this.snapshot});

  final DashboardDeviceSnapshot snapshot;

  String _localizeBatteryState(BatteryState? state) {
    if (state == null) return 'battery_state_unknown'.tr();
    return 'battery_state_${state.name}'.tr();
  }

  String _shortSummary(BuildContext context) {
    final String bat = snapshot.batteryPercent != null
        ? '${snapshot.batteryPercent}%'
        : '—';
    final String place = <String?>[
      snapshot.locality,
      snapshot.isoCountryCode,
    ].whereType<String>().where((String x) => x.isNotEmpty).join(', ');
    final String placeShort = place.isEmpty
        ? '—'
        : (place.length > 28 ? '${place.substring(0, 25)}…' : place);
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    final String time = loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(snapshot.sampledAt),
    );
    return '$bat · $placeShort · $time';
  }

  @override
  Widget build(BuildContext context) {
    final String placeLong = <String?>[
      snapshot.locality,
      snapshot.isoCountryCode,
    ].whereType<String>().where((String x) => x.isNotEmpty).join(', ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey<String>('dashboard_status_tile'),
        title: Row(
          children: <Widget>[
            Icon(
              Icons.sensors,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _shortSummary(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Tap for device details and conditions',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _infoRow(
                  context,
                  Icons.battery_std,
                  'Battery',
                  snapshot.batteryPercent != null
                      ? '${snapshot.batteryPercent}% (${_localizeBatteryState(snapshot.batteryState)})'
                      : '—',
                ),
                const SizedBox(height: 8),
                _infoRow(
                  context,
                  Icons.place_outlined,
                  'Place',
                  placeLong.isEmpty ? '—' : placeLong,
                ),
                const SizedBox(height: 8),
                _infoRow(
                  context,
                  Icons.my_location,
                  'Coordinates',
                  snapshot.hasFix
                      ? '${snapshot.latitude!.toStringAsFixed(5)}, ${snapshot.longitude!.toStringAsFixed(5)}'
                      : '—',
                ),
                const SizedBox(height: 8),
                _infoRow(
                  context,
                  Icons.schedule,
                  'Sampled at',
                  '${MaterialLocalizations.of(context).formatMediumDate(snapshot.sampledAt)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(snapshot.sampledAt))}',
                ),
                if (snapshot.locationError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    snapshot.locationError!.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const Divider(height: 28),
                Text(
                  'Day / night',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const DashboardWeatherCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData i, String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(i, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(k, style: Theme.of(context).textTheme.labelMedium),
              Text(v, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
