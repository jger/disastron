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
import 'package:disastron/router/providers/login_provider.dart';
import 'package:disastron/router/routes.gr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGuard extends AutoRouteGuard {
  AuthGuard({required this.ref});

  final Ref ref;
  final auth = false;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    if (await ref.watch(isLoggedInProvider.notifier).getLogged()) {
      resolver.next();
    } else {
      await router.replaceAll([const LoginRoute()]);
    }
  }
}
