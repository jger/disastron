/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved. This software and associated documentation files
/// (the "Software") may not be used, copied, modified, merged, published,
/// distributed, sublicensed, or sold, without the prior written permission
/// of the copyright holder.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
/// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
/// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
/// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
/// DEALINGS IN THE SOFTWARE.
/// ***************************************************************************

library;

import 'package:disastron/app/app_appearance.dart';
import 'package:disastron/app/app_locales.dart';
import 'package:disastron/app/appearance_provider.dart';
import 'package:disastron/app/locale_easy_bridge.dart';
import 'package:disastron/app/locale_provider.dart';
import 'package:disastron/features/home/model/huggingface_token_store.dart';
import 'package:disastron/router/providers/app_router_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final String? hfToken = await HuggingfaceTokenStore().read();
  await FlutterGemma.initialize(huggingFaceToken: hfToken);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool initialDone = prefs.getBool(kLanguageInitialDoneKey) ?? false;
  final String? saved = prefs.getString(kLocaleCodePrefsKey);
  final String startCode = initialDone &&
          saved != null &&
          AppLocales.codes.contains(saved)
      ? saved
      : AppLocales.codes.first;
  runApp(
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      path: 'assets/translations',
      fallbackLocale: AppLocales.localeFromCode(AppLocales.codes.first),
      startLocale: AppLocales.localeFromCode(startCode),
      child: const ProviderScope(
        child: LocaleEasyBridge(
          child: MyApp(),
        ),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final AsyncValue<AppAppearanceMode> appearance = ref.watch(appAppearanceProvider);
    return appearance.when(
      data: (AppAppearanceMode mode) {
        return MaterialApp.router(
          themeMode: mode.isDark ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          routeInformationParser: router.defaultRouteParser(),
          routeInformationProvider: router.routeInfoProvider(),
          routerDelegate: router.delegate(),
          theme: buildLightTheme(highContrast: mode == AppAppearanceMode.lightHighContrast),
          darkTheme: buildDarkTheme(highContrast: mode == AppAppearanceMode.darkHighContrast),
        );
      },
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: buildLightTheme(highContrast: false),
        darkTheme: buildDarkTheme(highContrast: true),
        themeMode: ThemeMode.dark,
        home: const SizedBox.shrink(),
      ),
      error: (Object _, StackTrace __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: buildLightTheme(highContrast: false),
        darkTheme: buildDarkTheme(highContrast: true),
        themeMode: ThemeMode.dark,
        home: const SizedBox.shrink(),
      ),
    );
  }
}
