/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'package:disastron/app/app_locales.dart';
import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:disastron/features/inference/data/huggingface_token_store.dart';
import 'package:disastron/features/inference/data/predefined_models_loader.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Startup helpers. Call initializeGemma after EasyLocalization is initialized
/// so localization is ready before runApp; Gemma init stays independent of locale.
abstract final class AppBootstrap {
  AppBootstrap._();

  static Future<void> loadPredefinedInferenceModels() =>
      PredefinedInferenceModelsLoader.ensureLoaded();

  static Future<void> initializeGemma() async {
    final String? hfToken = await HuggingfaceTokenStore().read();
    await FlutterGemma.initialize(huggingFaceToken: hfToken);
  }

  /// Re-initializes Gemma after the user saves or clears the HF token in settings.
  static Future<void> initializeGemmaWithToken(String? token) async {
    final String trimmed = token?.trim() ?? '';
    if (trimmed.isEmpty) {
      await FlutterGemma.initialize();
    } else {
      await FlutterGemma.initialize(huggingFaceToken: trimmed);
    }
  }

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
