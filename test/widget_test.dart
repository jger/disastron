import 'package:disastron/app/app_locales.dart';
import 'package:disastron/app/locale_easy_bridge.dart';
import 'package:disastron/features/inference/data/predefined_models_loader.dart';
import 'package:disastron/main.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
    await PredefinedInferenceModelsLoader.ensureLoaded();
  });

  testWidgets('app builds with ProviderScope and EasyLocalization',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        path: 'assets/translations',
        fallbackLocale: AppLocales.localeFromCode(AppLocales.codes.first),
        startLocale: AppLocales.localeFromCode(AppLocales.codes.first),
        child: const ProviderScope(
          child: LocaleEasyBridge(
            child: MyApp(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MaterialApp), findsWidgets);
  });
}
