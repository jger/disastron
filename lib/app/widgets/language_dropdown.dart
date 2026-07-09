import 'package:disastron/app/app_locales.dart';
import 'package:disastron/app/locale_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguageDropdown extends ConsumerWidget {
  const LanguageDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppLocaleState> asyncLocale = ref.watch(appLocaleProvider);
    return asyncLocale.when(
      data: (AppLocaleState s) => InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: 'language_label'.tr(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: s.localeCode,
            isExpanded: true,
            items: AppLocales.codes
                .map(
                  (String code) => DropdownMenuItem<String>(
                    value: code,
                    child: Text(AppLocales.displayNameKey(code).tr()),
                  ),
                )
                .toList(),
            onChanged: (String? next) {
              if (next != null) {
                ref.read(appLocaleProvider.notifier).setLocaleCode(next);
              }
            },
          ),
        ),
      ),
      loading: () => const LinearProgressIndicator(),
      error: (Object _, StackTrace _) => const SizedBox.shrink(),
    );
  }
}
