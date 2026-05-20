import 'package:flutter/material.dart';

/// In-app appearance (not system); includes dedicated high-contrast themes.
enum AppAppearanceMode {
  light,
  dark,
  lightHighContrast,
  darkHighContrast,
}

extension AppAppearanceModeX on AppAppearanceMode {
  bool get isDark =>
      this == AppAppearanceMode.dark || this == AppAppearanceMode.darkHighContrast;

  bool get isHighContrast =>
      this == AppAppearanceMode.lightHighContrast ||
      this == AppAppearanceMode.darkHighContrast;
}

ThemeData buildLightTheme({required bool highContrast}) {
  if (highContrast) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.highContrastLight(),
      visualDensity: VisualDensity.standard,
    );
  }
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    visualDensity: VisualDensity.standard,
  );
}

ThemeData buildDarkTheme({required bool highContrast}) {
  if (highContrast) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.highContrastDark(),
      visualDensity: VisualDensity.standard,
    );
  }
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    ),
    visualDensity: VisualDensity.standard,
  );
}

ThemeData themeForAppearance(AppAppearanceMode mode) {
  return switch (mode) {
    AppAppearanceMode.light => buildLightTheme(highContrast: false),
    AppAppearanceMode.lightHighContrast => buildLightTheme(highContrast: true),
    AppAppearanceMode.dark => buildDarkTheme(highContrast: false),
    AppAppearanceMode.darkHighContrast => buildDarkTheme(highContrast: true),
  };
}
