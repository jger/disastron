// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

/// Single place for SharedPreferences keys used across the app.
abstract final class PrefsKeys {
  PrefsKeys._();

  static const String localeCode = 'app_locale_code';
  static const String languageInitialDone = 'app_language_initial_done';
  static const String appearanceMode = 'app_appearance_mode_v1';
  static const String emergencyTodos = 'emergency_todos_v1';
  static const String pendingModelDownload = 'pending_model_download_v1';
}
