import 'package:auto_route/auto_route.dart';
import 'package:disastron/app/widgets/appearance_dropdown.dart';
import 'package:disastron/app/widgets/language_dropdown.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

@RoutePage()
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('appearance_title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'appearance_intro'.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const AppearanceDropdown(),
          const SizedBox(height: 24),
          const LanguageDropdown(),
        ],
      ),
    );
  }
}
