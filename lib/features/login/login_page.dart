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

import 'dart:developer';

import 'package:auto_route/auto_route.dart';
import 'package:disastron/router/providers/login_provider.dart';
import 'package:disastron/router/routes.gr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:svg_flutter/svg.dart';

@RoutePage()
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO(jge): implement build
    return Scaffold(
      /// Show a login button
      /// When the button is pressed, navigate to the home page
      /// using the router
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // logo here
            SvgPicture.asset('assets/images/logo.svg', height: 120),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                log('Login button pressed', name: 'LoginPage');
                ref.read(isLoggedInProvider.notifier).setLogged(isLoggedIn: true);
                AutoRouter.of(context).replace(const HomeRoute());
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
