import 'package:disastron/router/auth_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authGuardProvider = Provider<AuthGuard>((ref) {
  return AuthGuard(ref: ref);
});
