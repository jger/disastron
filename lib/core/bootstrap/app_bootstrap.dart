// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/app/app_locales.dart';
import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide startup helpers (locale). Inference engines: InferenceBootstrap.
abstract final class AppBootstrap {
  AppBootstrap._();

  /// Locale code for EasyLocalization startLocale before ProviderScope runs.
  static Future<String> resolveStartLocaleCode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool initialDone =
        prefs.getBool(PrefsKeys.languageInitialDone) ?? false;
    final String? saved = prefs.getString(PrefsKeys.localeCode);
    if (initialDone && saved != null && AppLocales.codes.contains(saved)) {
      return saved;
    }
    return AppLocales.codes.first;
  }
}
