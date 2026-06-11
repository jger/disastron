import 'package:disastron/app/app_locales.dart';
import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

class AppLocaleState {
  const AppLocaleState({
    required this.localeCode,
    required this.initialChoiceDone,
    required this.termsAccepted,
  });

  final String localeCode;
  final bool initialChoiceDone;
  final bool termsAccepted;

  Locale get locale => AppLocales.localeFromCode(localeCode);
}

@Riverpod(keepAlive: true)
class AppLocale extends _$AppLocale {
  @override
  Future<AppLocaleState> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool initialChoiceDone =
        prefs.getBool(PrefsKeys.languageInitialDone) ?? false;
    final bool termsAccepted =
        prefs.getBool(PrefsKeys.termsAccepted) ?? false;
    final String code =
        prefs.getString(PrefsKeys.localeCode) ?? AppLocales.codes.first;
    final String safe =
        AppLocales.codes.contains(code) ? code : AppLocales.codes.first;
    return AppLocaleState(
      localeCode: safe,
      initialChoiceDone: initialChoiceDone,
      termsAccepted: termsAccepted,
    );
  }

  Future<void> setLocaleCode(String code) async {
    final String safe =
        AppLocales.codes.contains(code) ? code : AppLocales.codes.first;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.localeCode, safe);
    final AppLocaleState cur = state.value ?? await future;
    state = AsyncValue<AppLocaleState>.data(
      AppLocaleState(
        localeCode: safe,
        initialChoiceDone: cur.initialChoiceDone,
        termsAccepted: cur.termsAccepted,
      ),
    );
  }

  Future<void> completeInitialChoice(String code) async {
    final String safe =
        AppLocales.codes.contains(code) ? code : AppLocales.codes.first;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.localeCode, safe);
    await prefs.setBool(PrefsKeys.languageInitialDone, true);
    final AppLocaleState cur = state.value ?? await future;
    state = AsyncValue<AppLocaleState>.data(
      AppLocaleState(
        localeCode: safe,
        initialChoiceDone: true,
        termsAccepted: cur.termsAccepted,
      ),
    );
  }

  Future<void> acceptTerms() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.termsAccepted, true);
    final AppLocaleState cur = state.value ?? await future;
    state = AsyncValue<AppLocaleState>.data(
      AppLocaleState(
        localeCode: cur.localeCode,
        initialChoiceDone: cur.initialChoiceDone,
        termsAccepted: true,
      ),
    );
  }
}
