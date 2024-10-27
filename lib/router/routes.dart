/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved. This software and associated documentation files
/// (the "Software") may not be used, copied, modified, merged, published,
/// distributed, sublicensed, or sold, without the prior written permission
/// of the copyright holder.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
/// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
/// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
/// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
/// DEALINGS IN THE SOFTWARE.
/// ***************************************************************************

library;

import 'package:auto_route/auto_route.dart';
import 'package:disastron/router/auth_guard.dart';
import 'package:disastron/router/routes.gr.dart';

@AutoRouterConfig(
  generateForDir: ['lib'],
  replaceInRouteName: 'Page,Route',
)
class AppRouter extends RootStackRouter {
  AppRouter({required this.authGuard});

  final AuthGuard authGuard;

  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: HomeRoute.page,
          path: '/',
          guards: [authGuard],
        ),
        AutoRoute(
          page: LoginRoute.page,
          path: '/login',
          initial: true,
        ),
        AutoRoute(
          page: GetPhotoRoute.page,
          path: '/get-photo',
          guards: [authGuard],
        ),
        RedirectRoute(path: '*', redirectTo: '/login'),
      ];
}
