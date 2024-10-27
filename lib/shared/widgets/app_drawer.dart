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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        children: [
          // Drawer header with a user account and logout button
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_circle,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'User Foo',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    // Logout icon
                    IconButton(
                      onPressed: () {
                        ref
                            .read(isLoggedInProvider.notifier)
                            .setLogged(isLoggedIn: false);
                        AutoRouter.of(context).replace(const LoginRoute());
                      },
                      icon: Icon(
                        Icons.logout,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          ListTile(
            title: const Text('Home'),
            onTap: () {
              AutoRouter.of(context).replace(const HomeRoute());
              // close drawer
              Navigator.pop(context);
            },
          ),

          ListTile(
            title: const Text('Get Photo'),
            onTap: () {
              AutoRouter.of(context).replace(const GetPhotoRoute());
              // close drawer
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
