// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/app/app_locales.dart';
import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:disastron/features/inference/data/huggingface_token_store.dart';
import 'package:disastron/features/inference/data/model_download_resume_service.dart';
import 'package:disastron/features/inference/data/predefined_models_loader.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Startup helpers. Call initializeGemma after EasyLocalization is initialized
/// so localization is ready before runApp; Gemma init stays independent of locale.
abstract final class AppBootstrap {
  AppBootstrap._();

  static Future<void> loadPredefinedInferenceModels() =>
      PredefinedInferenceModelsLoader.ensureLoaded();

  /// Registers the inference engines Disastron ships and initializes Edge AI.
  ///
  /// [FlutterEdgeAi.initialize] must pass `inferenceEngines` or the first
  /// `getActiveModel` throws. Both [LiteRtLmEngine] and [MediaPipeEngine] are
  /// required for presets in `assets/data/inference_models.yaml`.
  static Future<void> _initializeGemma(String? huggingFaceToken) async {
    await FlutterEdgeAi.initialize(
      huggingFaceToken: huggingFaceToken,
      inferenceEngines: const [LiteRtLmEngine(), MediaPipeEngine()],
    );
    await ModelDownloadResumeService.prepareOnStartup();
  }

  static Future<void> initializeGemma() async =>
      _initializeGemma(await HuggingfaceTokenStore().read());

  /// Re-initializes Gemma after the user saves or clears the HF token in settings.
  static Future<void> initializeGemmaWithToken(String? token) async {
    final String trimmed = token?.trim() ?? '';
    await _initializeGemma(trimmed.isEmpty ? null : trimmed);
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
