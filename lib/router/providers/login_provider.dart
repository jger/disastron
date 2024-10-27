import 'package:flutter_riverpod/flutter_riverpod.dart';

final isLoggedInProvider =
    StateNotifierProvider<IsLoggedInNotifier, bool>((ref) {
  return IsLoggedInNotifier();
});

class IsLoggedInNotifier extends StateNotifier<bool> {
  IsLoggedInNotifier() : super(false);

  bool _isLoggedIn = false;

  Future<bool> getLogged() async {
    return _isLoggedIn;
  }

  Future<void> setLogged({required bool isLoggedIn}) async {
    _isLoggedIn = isLoggedIn;
  }
}
