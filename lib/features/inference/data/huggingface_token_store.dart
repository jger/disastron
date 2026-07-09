import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keychain / Keystore-backed HF token (migrates one-time from legacy SharedPreferences).
class HuggingfaceTokenStore {
  HuggingfaceTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _secureKey = 'disastron_hf_token';
  static const String _legacyPrefKey = 'disastron_hf_token';

  Future<String?> read() async {
    final String? secure = (await _storage.read(key: _secureKey))?.trim();
    if (secure != null && secure.isNotEmpty) {
      return secure;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? legacy = prefs.getString(_legacyPrefKey)?.trim();
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(key: _secureKey, value: legacy);
      await prefs.remove(_legacyPrefKey);
      return legacy;
    }
    return null;
  }

  Future<void> write(String value) async {
    await _storage.write(key: _secureKey, value: value.trim());
  }

  Future<void> clear() async {
    await _storage.delete(key: _secureKey);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefKey);
  }
}
