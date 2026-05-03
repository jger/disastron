import 'package:auto_route/auto_route.dart';
import 'package:disastron/app/widgets/appearance_dropdown.dart';
import 'package:flutter/material.dart';

@RoutePage()
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme & appearance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Choose a theme. High-contrast dark saves battery on OLED.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const AppearanceDropdown(),
        ],
      ),
    );
  }
}
