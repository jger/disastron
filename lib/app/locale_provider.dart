import 'package:disastron/app/app_locales.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

const String kLocaleCodePrefsKey = 'app_locale_code';
const String kLanguageInitialDoneKey = 'app_language_initial_done';

class AppLocaleState {
  const AppLocaleState({
    required this.localeCode,
    required this.initialChoiceDone,
  });

  final String localeCode;
  final bool initialChoiceDone;

  Locale get locale => AppLocales.localeFromCode(localeCode);
}

@Riverpod(keepAlive: true)
class AppLocale extends _$AppLocale {
  @override
  Future<AppLocaleState> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool initialChoiceDone =
        prefs.getBool(kLanguageInitialDoneKey) ?? false;
    final String code =
        prefs.getString(kLocaleCodePrefsKey) ?? AppLocales.codes.first;
    final String safe =
        AppLocales.codes.contains(code) ? code : AppLocales.codes.first;
    return AppLocaleState(
      localeCode: safe,
      initialChoiceDone: initialChoiceDone,
    );
  }

  Future<void> setLocaleCode(String code) async {
    final String safe =
        AppLocales.codes.contains(code) ? code : AppLocales.codes.first;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLocaleCodePrefsKey, safe);
    final AppLocaleState cur =
        state.value ?? await future;
    state = AsyncValue<AppLocaleState>.data(
      AppLocaleState(
        localeCode: safe,
        initialChoiceDone: cur.initialChoiceDone,
      ),
    );
  }

  Future<void> completeInitialChoice(String code) async {
    final String safe =
        AppLocales.codes.contains(code) ? code : AppLocales.codes.first;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLocaleCodePrefsKey, safe);
    await prefs.setBool(kLanguageInitialDoneKey, true);
    state = AsyncValue<AppLocaleState>.data(
      AppLocaleState(localeCode: safe, initialChoiceDone: true),
    );
  }
}
