import 'dart:async';

import 'package:disastron/app/app_locales.dart';
import 'package:disastron/app/locale_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps [EasyLocalization] in sync with persisted [appLocaleProvider].
class LocaleEasyBridge extends ConsumerStatefulWidget {
  const LocaleEasyBridge({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LocaleEasyBridge> createState() => _LocaleEasyBridgeState();
}

class _LocaleEasyBridgeState extends ConsumerState<LocaleEasyBridge> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppLocaleState>>(appLocaleProvider,
        (_, AsyncValue<AppLocaleState> next) {
      next.whenData((AppLocaleState s) {
        final Locale loc = AppLocales.localeFromCode(s.localeCode);
        if (context.locale != loc) {
          unawaited(context.setLocale(loc));
        }
      });
    });

    return widget.child;
  }
}
