import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:disastron/app/app_appearance.dart';
import 'package:disastron/app/appearance_provider.dart';
import 'package:disastron/app/locale_provider.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_device_provider.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_weather_provider.dart';
import 'package:disastron/features/dashboard/presentation/widgets/dashboard_action_card.dart';
import 'package:disastron/features/dashboard/presentation/widgets/dashboard_weather_card.dart';
import 'package:disastron/features/inference/domain/predefined_models.dart';
import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:disastron/features/inference/presentation/model_install_flow_coordinator.dart';
import 'package:disastron/features/inference/presentation/widgets/interrupted_download_panel.dart';
import 'package:disastron/features/inference/presentation/widgets/model_install_progress_panel.dart';
import 'package:disastron/features/inference/presentation/widgets/preset_download_metadata.dart';
import 'package:disastron/features/tool_layout/domain/app_tool.dart';
import 'package:disastron/features/tool_layout/domain/app_tool_catalog.dart';
import 'package:disastron/features/tool_layout/presentation/open_app_tool.dart';
import 'package:disastron/features/tool_layout/presentation/tool_layout_labels.dart';
import 'package:disastron/features/tool_layout/presentation/tool_placements_provider.dart';
import 'package:disastron/features/wiki/presentation/wiki_models.dart';
import 'package:disastron/features/wiki/presentation/wiki_pack_provider.dart';
import 'package:disastron/router/routes.gr.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dark-HC battery tip; close hides until user leaves this theme.
class _HcBatteryTipBanner extends ConsumerStatefulWidget {
  const _HcBatteryTipBanner();

  @override
  ConsumerState<_HcBatteryTipBanner> createState() =>
      _HcBatteryTipBannerState();
}

class _HcBatteryTipBannerState extends ConsumerState<_HcBatteryTipBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(
      appAppearanceProvider,
      (
        AsyncValue<AppAppearanceMode>? previous,
        AsyncValue<AppAppearanceMode> next,
      ) {
        next.whenData((AppAppearanceMode m) {
          if (m != AppAppearanceMode.darkHighContrast && mounted) {
            setState(() => _dismissed = false);
          }
        });
      },
    );

    final AsyncValue<AppAppearanceMode> appearance =
        ref.watch(appAppearanceProvider);

    return appearance.when(
      data: (AppAppearanceMode m) {
        if (m != AppAppearanceMode.darkHighContrast || _dismissed) {
          return const SizedBox.shrink();
        }
        final Color onSec = Theme.of(context).colorScheme.onSecondaryContainer;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.battery_saver_outlined,
                    color: onSec,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'battery_tip_body'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: onSec,
                          ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      unawaited(
                        ref
                            .read(appAppearanceProvider.notifier)
                            .setMode(AppAppearanceMode.light),
                      );
                    },
                    child: Text(
                      'light_mode'.tr(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: onSec,
                          ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    icon: Icon(Icons.close, color: onSec, size: 22),
                    tooltip: 'dismiss'.tr(),
                    onPressed: () => setState(() => _dismissed = true),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Banner for offline model: progress while downloading, CTA when none installed.
class _NoOfflineModelBanner extends ConsumerWidget {
  const _NoOfflineModelBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LocalGemmaModelUi ui = ref.watch(localGemmaModelProvider);

    if (ui.phase == LocalGemmaPhase.installing) {
      return const ModelInstallProgressPanel(
        variant: ModelInstallProgressVariant.dashboardBanner,
      );
    }

    if (ui.phase == LocalGemmaPhase.downloadInterrupted) {
      return const InterruptedDownloadPanel(compact: true);
    }

    if (ui.phase != LocalGemmaPhase.notInstalled) {
      return const SizedBox.shrink();
    }
    final PredefinedInferenceModel m = kDefaultInferencePreset;
    final Color onC = Theme.of(context).colorScheme.onErrorContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.smart_toy_outlined, color: onC, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'no_offline_model_title'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: onC,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'no_offline_model_body'.tr(
                  namedArgs: <String, String>{
                    'preset': m.title,
                  },
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onC,
                    ),
              ),
              const SizedBox(height: 8),
              PresetDownloadMetadataChips(model: m),
              const SizedBox(height: 4),
              Text(
                m.downloadMetadataLine,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onC,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () =>
                        context.router.push(const ModelConfigRoute()),
                    child: Text('offline_model_settings'.tr()),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (!context.mounted) {
                        return;
                      }
                      final bool ok =
                          await coordinateInferenceNetworkInstallPreflight(
                        context: context,
                        ref: ref,
                        model: m,
                      );
                      if (!ok || !context.mounted) {
                        return;
                      }
                      await ref
                          .read(localGemmaModelProvider.notifier)
                          .installPresetById(kDefaultInferencePresetId);
                    },
                    child: Text('download_smallest'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          ..invalidate(dashboardDeviceProvider)
          ..invalidate(dashboardWeatherProvider);
      },
      child: const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _DashboardStatusCard(),
            SizedBox(height: 16),
            _NoOfflineModelBanner(),
            SizedBox(height: 16),
            _HcBatteryTipBanner(),
            SizedBox(height: 16),
            _DashboardToolGrid(),
          ],
        ),
      ),
    );
  }
}

class _DashboardToolGrid extends ConsumerWidget {
  const _DashboardToolGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, ToolPlacementFlags>> placementsAsync =
        ref.watch(toolPlacementsProvider);
    final AsyncValue<WikiPack> wikiAsync = ref.watch(wikiPackProvider);

    return placementsAsync.when(
      data: (Map<String, ToolPlacementFlags> placements) {
        return wikiAsync.when(
          data: (WikiPack wikiPack) {
            final List<String> toolIds = AppToolCatalog.idsForSurface(
              placements,
              AppToolSurface.dashboard,
            );
            if (toolIds.isEmpty) {
              return const SizedBox.shrink();
            }
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double w = c.maxWidth;
                final int cols = w >= 520 ? 3 : 2;
                final List<Widget> cards = toolIds.map((String toolId) {
                  final AppToolDefinition def =
                      AppToolCatalog.definitionFor(toolId);
                  final ToolLayoutLabels labels = labelsForTool(
                    toolId,
                    wikiPack: wikiPack,
                  );
                  return DashboardActionCard(
                    icon: def.icon,
                    title: labels.title,
                    subtitle: labels.subtitle ?? '',
                    onTap: () => openAppTool(context, ref, toolId),
                  );
                }).toList();
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3 / 2,
                  children: cards,
                );
              },
            );
          },
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _DashboardStatusCard extends ConsumerWidget {
  const _DashboardStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardDeviceSnapshot> async =
        ref.watch(dashboardDeviceProvider);

    return async.when(
      data: (DashboardDeviceSnapshot s) => _StatusExpansionTile(snapshot: s),
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

class _StatusExpansionTile extends StatelessWidget {
  const _StatusExpansionTile({required this.snapshot});

  final DashboardDeviceSnapshot snapshot;

  String _shortSummary(BuildContext context) {
    final String bat =
        snapshot.batteryPercent != null ? '${snapshot.batteryPercent}%' : '—';
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
                      ? '${snapshot.batteryPercent}% (${snapshot.batteryState})'
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
              Text(
                k,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                v,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
