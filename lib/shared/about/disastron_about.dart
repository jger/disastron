// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:about/about.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:svg_flutter/svg_flutter.dart';

/// Opens the in-app About flow (package `about`) with standard OSS licenses.
Future<void> showDisastronAbout(
  BuildContext context, {
  required PackageInfo packageInfo,
}) {
  final String year = DateTime.now().year.toString();
  final String buildNumber = packageInfo.buildNumber;
  final String versionTemplate =
      buildNumber.isEmpty ? '{{ version }}' : '{{ version }}+{{ buildNumber }}';

  return showAboutPage(
    context: context,
    applicationName: 'app_name'.tr(),
    applicationVersion: versionTemplate,
    applicationLegalese: 'Copyright © {{ year }} Jannis Gerardis',
    values: <String, String>{
      'version': packageInfo.version,
      'buildNumber': buildNumber,
      'year': year,
    },
    applicationDescription: Text(
      'about_description'.tr(),
      textAlign: TextAlign.center,
    ),
    applicationIcon: SvgPicture.asset(
      'assets/images/logo.svg',
      height: 72,
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.96),
        BlendMode.srcIn,
      ),
      semanticsLabel: 'app_name'.tr(),
    ),
    children: <Widget>[
      LicensesPageListTile(
        icon: const Icon(Icons.description_outlined),
        title: Text('about_licenses'.tr()),
      ),
    ],
  );
}
