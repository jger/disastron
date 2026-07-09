// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:auto_route/auto_route.dart';
import 'package:disastron/router/routes.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  AppRouter();

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(page: HomeRoute.page, path: '/', initial: true),
    AutoRoute(page: DashboardRoute.page, path: '/dashboard'),
    AutoRoute(page: MessagesRoute.page, path: '/chat'),
    AutoRoute(page: TodosRoute.page, path: '/todos'),
    AutoRoute(page: WikiRoute.page, path: '/wiki'),
    AutoRoute(page: WikiConfigRoute.page, path: '/wiki/config'),
    AutoRoute(page: WikiWebviewRoute.page, path: '/wiki/webview'),
    AutoRoute(page: AppearanceSettingsRoute.page, path: '/settings/appearance'),
    AutoRoute(page: ModelConfigRoute.page, path: '/settings/model'),
    AutoRoute(
      page: ToolLayoutSettingsRoute.page,
      path: '/settings/tool-layout',
    ),
    RedirectRoute(path: '*', redirectTo: '/'),
  ];
}
