// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:disastron/app/app_appearance.dart';
import 'package:disastron/app/appearance_provider.dart';
import 'package:disastron/app/locale_provider.dart';
import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:disastron/features/home/home.dart';
import 'package:disastron/features/inference/inference.dart';
import 'package:disastron/features/wiki/wiki.dart';
import 'package:disastron/router/routes.gr.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dark-HC battery tip; close hides until user leaves this theme.
class DashboardHcBatteryTipBanner extends ConsumerStatefulWidget {
  const DashboardHcBatteryTipBanner({super.key});

  @override
  ConsumerState<DashboardHcBatteryTipBanner> createState() =>
      _DashboardHcBatteryTipBannerState();
}

class _DashboardHcBatteryTipBannerState
    extends ConsumerState<DashboardHcBatteryTipBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(appAppearanceProvider, (
      AsyncValue<AppAppearanceMode>? previous,
      AsyncValue<AppAppearanceMode> next,
    ) {
      next.whenData((AppAppearanceMode m) {
        if (m != AppAppearanceMode.darkHighContrast && mounted) {
          setState(() => _dismissed = false);
        }
      });
    });

    final AsyncValue<AppAppearanceMode> appearance = ref.watch(
      appAppearanceProvider,
    );

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
                  Icon(Icons.battery_saver_outlined, color: onSec),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'battery_tip_body'.tr(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: onSec),
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
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: onSec),
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
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Banner for offline model: progress while downloading, CTA when none installed.
class DashboardNoOfflineModelBanner extends ConsumerWidget {
  const DashboardNoOfflineModelBanner({super.key});

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
                  namedArgs: <String, String>{'preset': m.title},
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onC),
              ),
              const SizedBox(height: 8),
              PresetDownloadMetadataChips(model: m),
              const SizedBox(height: 4),
              Text(
                m.downloadMetadataLine,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onC),
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

class DashboardNoOfflineWikiBanner extends ConsumerStatefulWidget {
  const DashboardNoOfflineWikiBanner({super.key});

  @override
  ConsumerState<DashboardNoOfflineWikiBanner> createState() =>
      _DashboardNoOfflineWikiBannerState();
}

class _DashboardNoOfflineWikiBannerState
    extends ConsumerState<DashboardNoOfflineWikiBanner> {
  bool _dismissed = false;
  bool _loadingDismissState = true;

  @override
  void initState() {
    super.initState();
    _loadDismissState();
  }

  Future<void> _loadDismissState() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool dismissed =
          prefs.getBool(PrefsKeys.wikiYamlSyncBannerDismissed) ?? false;
      if (mounted) {
        setState(() {
          _dismissed = dismissed;
          _loadingDismissState = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingDismissState = false;
        });
      }
    }
  }

  Future<void> _dismissBanner() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefsKeys.wikiYamlSyncBannerDismissed, true);
      if (mounted) {
        setState(() {
          _dismissed = true;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDismissState || _dismissed) {
      return const SizedBox.shrink();
    }

    final localeAsync = ref.watch(appLocaleProvider);
    final String locale = localeAsync.maybeWhen(
      data: (s) => s.localeCode,
      orElse: () => 'en',
    );

    final sourcesAsync = ref.watch(wikiSourcesProvider);
    final downloadsAsync = ref.watch(wikiDownloadProvider);

    if (sourcesAsync.isLoading || downloadsAsync.isLoading) {
      return const SizedBox.shrink();
    }

    final sources = sourcesAsync.value ?? [];
    final downloads = downloadsAsync.value ?? {};

    final localSources = sources.where((s) => s.locale == locale).toList();
    if (localSources.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool hasDownloaded = localSources.any((s) {
      final dlState = downloads[s.url];
      return dlState?.status == WikiDownloadStatus.downloaded;
    });

    if (hasDownloaded) {
      return const SizedBox.shrink();
    }

    final Color onC = Theme.of(context).colorScheme.onErrorContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Icon(Icons.menu_book_outlined, color: onC, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'no_offline_wiki_title'.tr(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: onC,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(Icons.close, color: onC, size: 20),
                    tooltip: 'dismiss'.tr(),
                    onPressed: _dismissBanner,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'no_offline_wiki_body'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: onC),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () {
                      ref.read(wikiSelectedTabProvider.notifier).state = 1;
                      ref.read(homeBottomNavIndexProvider.notifier).state = 3;
                    },
                    child: Text(
                      'wiki_go_to_sync'.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
