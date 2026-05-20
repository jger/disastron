import 'dart:async';

import 'package:disastron/app/app_appearance.dart';
import 'package:disastron/app/appearance_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppearanceDropdown extends ConsumerWidget {
  const AppearanceDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppAppearanceMode> appearanceAsync =
        ref.watch(appAppearanceProvider);
    return appearanceAsync.when(
      data: (AppAppearanceMode mode) => InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: 'theme_label'.tr(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AppAppearanceMode>(
            value: mode,
            isExpanded: true,
            items: AppAppearanceMode.values
                .map(
                  (AppAppearanceMode m) => DropdownMenuItem<AppAppearanceMode>(
                    value: m,
                    child: Text(appearanceLabel(m)),
                  ),
                )
                .toList(),
            onChanged: (AppAppearanceMode? next) {
              if (next != null) {
                unawaited(ref.read(appAppearanceProvider.notifier).setMode(next));
              }
            },
          ),
        ),
      ),
      loading: () => const LinearProgressIndicator(),
      error: (Object _, StackTrace __) => const SizedBox.shrink(),
    );
  }
}

String appearanceLabel(AppAppearanceMode m) {
  return switch (m) {
    AppAppearanceMode.light => 'theme_light'.tr(),
    AppAppearanceMode.dark => 'theme_dark'.tr(),
    AppAppearanceMode.lightHighContrast => 'theme_light_hc'.tr(),
    AppAppearanceMode.darkHighContrast => 'theme_dark_hc'.tr(),
  };
}
