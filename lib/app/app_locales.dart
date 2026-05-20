/// Supported UI / wiki locale codes (matches `assets/translations/*.json`).
library;

import 'package:flutter/material.dart';

/// BCP-style codes used in prefs and wiki filenames (`wiki_pack_<code>.json`).
abstract final class AppLocales {
  static const List<String> codes = <String>[
    'en',
    'de',
    'fr',
    'es',
    'el',
    'zh',
    'ar',
  ];

  static List<Locale> get supported => codes.map(localeFromCode).toList();

  static Locale localeFromCode(String code) {
    switch (code) {
      case 'zh':
        return const Locale('zh');
      default:
        return Locale(code);
    }
  }

  /// Inverse of [localeFromCode] for prefs / filenames (drops script where fixed).
  static String codeFromLocale(Locale locale) {
    return locale.languageCode;
  }

  static String displayNameKey(String code) => 'lang_$code';
}
