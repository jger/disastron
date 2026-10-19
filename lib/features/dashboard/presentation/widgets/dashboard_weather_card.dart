import 'package:disastron/features/dashboard/domain/light_state_calculator.dart';
import 'package:disastron/features/dashboard/domain/location_error_messages.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_weather_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardWeatherCard extends ConsumerWidget {
  const DashboardWeatherCard({super.key});

  String _fmtTime(BuildContext context, DateTime? t) {
    if (t == null) {
      return '—';
    }
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(t));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardWeatherSnapshot> async = ref.watch(
      dashboardWeatherProvider,
    );

    return async.when(
      data: (DashboardWeatherSnapshot s) {
        final ThemeData theme = Theme.of(context);
        final ColorScheme cs = theme.colorScheme;
        final TextStyle small =
            (theme.textTheme.bodySmall ?? theme.textTheme.bodyMedium!).copyWith(
              color: cs.onSurfaceVariant,
            );

        if (!s.hasFix) {
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.wb_cloudy_outlined,
                        size: 20,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'dashboard_conditions'.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (s.locationError ??
                            DashboardLocationErrors.unavailableFallback)
                        .tr(),
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                  ),
                  const SizedBox(height: 4),
                  Text('location_gps_hint'.tr(), style: small),
                ],
              ),
            ),
          );
        }

        final LightStateResult? light = s.light;
        final bool polarNight = light?.isPolarNight ?? false;
        final bool polarDay = light?.isPolarDay ?? false;
        final bool isDay = light?.isDay ?? false;

        final String phaseLabel = polarNight
            ? 'dashboard_polar_night'.tr()
            : polarDay
            ? 'dashboard_polar_day'.tr()
            : isDay
            ? 'dashboard_day'.tr()
            : 'dashboard_night'.tr();

        final IconData phaseIcon = polarDay || (!polarNight && isDay)
            ? Icons.wb_sunny_outlined
            : Icons.nights_stay_outlined;

        final Color phaseColor = polarDay || (!polarNight && isDay)
            ? cs.primary
            : cs.tertiary;

        final MaterialLocalizations loc = MaterialLocalizations.of(context);

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(phaseIcon, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'dashboard_conditions'.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      avatar: Icon(phaseIcon, size: 16, color: phaseColor),
                      label: Text(
                        phaseLabel,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (light != null && !polarNight && !polarDay) ...<Widget>[
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodySmall,
                      children: <InlineSpan>[
                        TextSpan(
                          text: 'dashboard_sun_up'.tr(),
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        TextSpan(
                          text: _fmtTime(context, light.sunriseLocal),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: ' · ',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        TextSpan(
                          text: 'dashboard_sun_down'.tr(),
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        TextSpan(
                          text: _fmtTime(context, light.sunsetLocal),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (s.forecast != null || s.forecastError != null)
                    const SizedBox(height: 6),
                ] else if (light != null) ...<Widget>[
                  Text(
                    polarNight
                        ? 'dashboard_polar_night_desc'.tr()
                        : 'dashboard_polar_day_desc'.tr(),
                    style: small,
                  ),
                  if (s.forecast != null || s.forecastError != null)
                    const SizedBox(height: 4),
                ],
                if (s.forecast != null) ...<Widget>[
                  Text(
                    'dashboard_typical_temps'.tr(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'dashboard_typical_month_line'.tr(
                      args: <String>[
                        loc.formatShortMonthDay(
                          DateTime(2024, s.forecast!.month1to12),
                        ),
                        s.forecast!.dayAvgC.toStringAsFixed(1),
                        s.forecast!.nightAvgC.toStringAsFixed(1),
                      ],
                    ),
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'dashboard_climate_disclaimer'.tr(
                      args: <String>[
                        s.forecast!.nearestStationKm.toStringAsFixed(0),
                      ],
                    ),
                    style: small,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else if (s.forecastError != null)
                  Text(
                    s.forecastError!,
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SizedBox(height: 2, child: LinearProgressIndicator()),
        ),
      ),
      error: (Object e, StackTrace st) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Text(
            'dashboard_conditions_error'.tr(args: <String>['$e']),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}
