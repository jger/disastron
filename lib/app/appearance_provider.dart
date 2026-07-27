import 'package:disastron/app/app_appearance.dart';
import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'appearance_provider.g.dart';

@Riverpod(keepAlive: true)
class AppAppearance extends _$AppAppearance {
  @override
  Future<AppAppearanceMode> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(PrefsKeys.appearanceMode);
    if (raw == null) {
      return AppAppearanceMode.light;
    }
    return AppAppearanceMode.values.firstWhere(
      (AppAppearanceMode e) => e.name == raw,
      orElse: () => AppAppearanceMode.light,
    );
  }

  Future<void> setMode(AppAppearanceMode mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.appearanceMode, mode.name);
    state = AsyncValue<AppAppearanceMode>.data(mode);
  }
}
