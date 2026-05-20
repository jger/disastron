/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:disastron/router/routes.gr.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:svg_flutter/svg_flutter.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _starsController;

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: <Widget>[
          DrawerHeader(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF0B1020),
                  Color(0xFF101835),
                  Color(0xFF1A1440),
                ],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _starsController,
                    builder: (BuildContext context, Widget? child) {
                      return CustomPaint(
                        painter: _BlinkStarFieldPainter(
                          t: _starsController.value,
                        ),
                      );
                    },
                  ),
                ),
                Center(
                  child: SvgPicture.asset(
                    'assets/images/logo.svg',
                    height: 104,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withValues(alpha: 0.96),
                      BlendMode.srcIn,
                    ),
                    semanticsLabel: 'app_name'.tr(),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text('drawer_home'.tr()),
            onTap: () {
              AutoRouter.of(context).replace(const HomeRoute());
              Navigator.pop(context);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text('drawer_theme'.tr()),
            onTap: () {
              Navigator.pop(context);
              context.router.push(const AppearanceSettingsRoute());
            },
          ),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: Text('drawer_offline_model'.tr()),
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

/// Lightweight random-looking star field with twinkle via sine phases.
class _BlinkStarFieldPainter extends CustomPainter {
  _BlinkStarFieldPainter({required this.t});

  final double t;

  static const int _starCount = 42;

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random r = math.Random(42);
    for (int i = 0; i < _starCount; i++) {
      final double x = r.nextDouble() * size.width;
      final double y = r.nextDouble() * size.height;
      final double phase = r.nextDouble() * math.pi * 2;
      final double freq = 0.7 + r.nextDouble() * 1.8;
      final double blink =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * math.pi * 2 * freq + phase));
      final double radius = 0.7 + r.nextDouble() * 1.5;
      final Paint paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15 + 0.55 * blink)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlinkStarFieldPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}
