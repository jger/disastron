import 'package:disastron/app/app_appearance.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'appearance_provider.g.dart';

@Riverpod(keepAlive: true)
class AppAppearance extends _$AppAppearance {
  @override
  Future<AppAppearanceMode> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(kAppearancePrefsKey);
    if (raw == null) {
      return AppAppearanceMode.darkHighContrast;
    }
    return AppAppearanceMode.values.firstWhere(
      (AppAppearanceMode e) => e.name == raw,
      orElse: () => AppAppearanceMode.darkHighContrast,
    );
  }

  Future<void> setMode(AppAppearanceMode mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAppearancePrefsKey, mode.name);
    state = AsyncValue<AppAppearanceMode>.data(mode);
  }
}
