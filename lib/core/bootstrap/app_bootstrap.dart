// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/app/app_locales.dart';
import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:disastron/features/inference/data/huggingface_token_store.dart';
import 'package:disastron/features/inference/data/model_download_resume_service.dart';
import 'package:disastron/features/inference/data/predefined_models_loader.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Startup helpers. Call initializeGemma after EasyLocalization is initialized
/// so localization is ready before runApp; Gemma init stays independent of locale.
abstract final class AppBootstrap {
  AppBootstrap._();

  static Future<void> loadPredefinedInferenceModels() =>
      PredefinedInferenceModelsLoader.ensureLoaded();

  /// Registers the inference engines Disastron ships and initializes Gemma.
  ///
  /// flutter_gemma core registers no engine on its own. Omitting
  /// [FlutterGemma.initialize]'s `inferenceEngines` still compiles, and then
  /// throws on the first `getActiveModel` call — so this is the one part of the
  /// 1.x migration no static check catches.
  ///
  /// Both engines are required: presets in `assets/data/inference_models.yaml`
  /// cover `.litertlm` (LiteRT-LM) and `.task` / `.bin` (MediaPipe). The list is
  /// written inline because flutter_gemma 1.2.2 does not export
  /// `InferenceEngineProvider` from its barrel, so the type cannot be named
  /// without reaching into `package:flutter_gemma/core/registry/...`.
  static Future<void> _initializeGemma(String? huggingFaceToken) async {
    await FlutterGemma.initialize(
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
