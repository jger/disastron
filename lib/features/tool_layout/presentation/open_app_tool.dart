// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_device_provider.dart';
import 'package:disastron/features/dashboard/presentation/sos_overlay.dart';
import 'package:disastron/features/emergency/emergency_numbers.dart';
import 'package:disastron/features/emergency/presentation/providers/emergency_numbers_pack_provider.dart';
import 'package:disastron/features/tool_layout/domain/app_tool_catalog.dart';
import 'package:disastron/features/wiki/presentation/wiki_navigation.dart';
import 'package:disastron/router/routes.gr.dart';
import 'package:disastron/shared/about/disastron_about.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openAppTool(
  BuildContext context,
  WidgetRef ref,
  String toolId,
) async {
  switch (toolId) {
    case AppToolCatalog.callHelpId:
      await _openCallHelp(context, ref);
    case AppToolCatalog.sosId:
      await openSosOverlay(context);
    case AppToolCatalog.appearanceSettingsId:
      await context.router.push(const AppearanceSettingsRoute());
    case AppToolCatalog.offlineModelId:
      await context.router.push(const ModelConfigRoute());
    case AppToolCatalog.aboutId:
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (!context.mounted) {
        return;
      }
      await showDisastronAbout(context, packageInfo: info);
    default:
      if (AppToolCatalog.isWikiArticle(toolId)) {
        await openWikiArticleById(context, ref, toolId);
      }
  }
}

Future<void> _openCallHelp(BuildContext context, WidgetRef ref) async {
  final DashboardDeviceSnapshot snap =
      await ref.read(dashboardDeviceProvider.future);
  final EmergencyNumbersPack pack =
      await ref.read(emergencyNumbersPackProvider.future);
  final List<EmergencyNumberEntry> lines = pack.forCountry(snap.isoCountryCode);

  if (!context.mounted) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.paddingOf(ctx).bottom + 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'emergency_numbers'.tr(),
            style: Theme.of(ctx).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            snap.isoCountryCode != null
                ? 'tool_layout_call_help_region'
                    .tr(args: <String>[snap.isoCountryCode!])
                : 'tool_layout_call_help_region_unknown'.tr(),
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            itemCount: lines.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int i) {
              final EmergencyNumberEntry e = lines[i];
              final String telDigits =
                  e.number.replaceAll(RegExp(r'[^\d+]'), '');
              return ListTile(
                leading: const Icon(Icons.phone_in_talk),
                title: Text(e.label),
                subtitle: Text(e.number),
                onTap: () async {
                  final Uri uri = Uri(scheme: 'tel', path: telDigits);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              );
            },
          ),
        ],
      ),
    ),
  );
}
