import 'package:disastron/router/routes.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router_provider.g.dart';

@riverpod
AppRouter appRouter(Ref ref) {
  return AppRouter();
}
