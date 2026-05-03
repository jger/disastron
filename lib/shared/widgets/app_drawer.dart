/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'package:auto_route/auto_route.dart';
import 'package:disastron/router/routes.gr.dart';
import 'package:flutter/material.dart';
import 'package:svg_flutter/svg_flutter.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Drawer(
      child: ListView(
        children: <Widget>[
          DrawerHeader(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  cs.primary,
                  Color.lerp(cs.primary, cs.primaryContainer, 0.22)!,
                ],
              ),
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/logo.svg',
                height: 72,
                colorFilter: ColorFilter.mode(
                  cs.onPrimary,
                  BlendMode.srcIn,
                ),
                semanticsLabel: 'Disastron',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () {
              AutoRouter.of(context).replace(const HomeRoute());
              Navigator.pop(context);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme & appearance'),
            onTap: () {
              Navigator.pop(context);
              context.router.push(const AppearanceSettingsRoute());
            },
          ),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: const Text('Offline model'),
            onTap: () {
              Navigator.pop(context);
              context.router.push(const ModelConfigRoute());
            },
          ),
        ],
      ),
    );
  }
}
