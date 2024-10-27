import 'package:disastron/router/auth_guard.dart';
import 'package:disastron/router/routes.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router_provider.g.dart';

@riverpod
// ignore: unsupported_provider_value
AppRouter appRouter(AppRouterRef ref) {
  return AppRouter(
    authGuard: AuthGuard(ref: ref),
  );
}
