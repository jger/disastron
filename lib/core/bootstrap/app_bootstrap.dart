// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/app/app_locales.dart';
import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:disastron/features/inference/data/huggingface_token_store.dart';
import 'package:disastron/features/inference/data/model_download_resume_service.dart';
import 'package:disastron/features/inference/data/predefined_models_loader.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    await _initializeFlutterGemma(hfToken);
    await ModelDownloadResumeService.prepareOnStartup();
  }

  /// Re-initializes Gemma after the user saves or clears the HF token in settings.
  static Future<void> initializeGemmaWithToken(String? token) async {
    final String trimmed = token?.trim() ?? '';
    await _initializeFlutterGemma(trimmed.isEmpty ? null : trimmed);
    await ModelDownloadResumeService.prepareOnStartup();
  }

  static Future<void> _initializeFlutterGemma(String? hfToken) async {
    if (!kIsWeb) {
      await FlutterGemma.initialize(huggingFaceToken: hfToken);
      return;
    }
    try {
      await FlutterGemma.initialize(
        huggingFaceToken: hfToken,
        webStorageMode: WebStorageMode.streaming,
      );
    } on Object {
      // Missing opfs_helper.js or OPFS unsupported — fall back to cache API.
      await FlutterGemma.initialize(
        huggingFaceToken: hfToken,
      );
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
