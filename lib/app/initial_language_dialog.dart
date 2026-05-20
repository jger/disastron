import 'package:disastron/app/app_locales.dart';
import 'package:disastron/app/locale_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// First-launch language picker; must confirm before dismiss (barrier locked).
Future<void> showInitialLanguageDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AsyncValue<AppLocaleState> asyncLocale = ref.read(appLocaleProvider);
  String selected = asyncLocale.maybeWhen(
    data: (AppLocaleState s) => s.localeCode,
    orElse: () => AppLocales.codes.first,
  );

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (
          BuildContext context,
          void Function(void Function()) setState,
        ) {
          return AlertDialog(
            title: Text('initial_language_title'.tr()),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'initial_language_message'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: selected,
                    onChanged: (String? v) {
                      if (v != null) {
                        setState(() => selected = v);
                      }
                    },
                    child: Column(
                      children: AppLocales.codes
                          .map(
                            (String code) => RadioListTile<String>(
                              title: Text(
                                AppLocales.displayNameKey(code).tr(),
                              ),
                              value: code,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(appLocaleProvider.notifier)
                      .completeInitialChoice(selected);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                },
                child: Text('initial_language_continue'.tr()),
              ),
            ],
          );
        },
      );
    },
  );
}
