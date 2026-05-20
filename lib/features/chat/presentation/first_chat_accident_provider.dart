import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'first_chat_accident_provider.g.dart';

const String kFirstChatAccidentPromptDoneKey =
    'first_chat_accident_prompt_done_v1';

/// Persisted flag: when `true`, the first-run accident chip prompt was shown/completed.
@Riverpod(keepAlive: true)
class FirstChatAccidentPrompt extends _$FirstChatAccidentPrompt {
  @override
  Future<bool> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kFirstChatAccidentPromptDoneKey) ?? false;
  }

  Future<void> markDone() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kFirstChatAccidentPromptDoneKey, true);
    state = const AsyncValue<bool>.data(true);
  }

  /// Clears persisted first-run state so accident chips show again (empty chat).
  Future<void> reset() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(kFirstChatAccidentPromptDoneKey);
    state = const AsyncValue<bool>.data(false);
  }
}
