// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/tool_layout/domain/app_tool.dart';
import 'package:disastron/features/tool_layout/domain/app_tool_catalog.dart';
import 'package:disastron/features/tool_layout/presentation/open_app_tool.dart';
import 'package:disastron/features/tool_layout/presentation/tool_layout_labels.dart';
import 'package:disastron/features/tool_layout/presentation/tool_placements_provider.dart';
import 'package:disastron/features/wiki/presentation/wiki_models.dart';
import 'package:disastron/features/wiki/presentation/wiki_pack_provider.dart';
import 'package:disastron/router/routes.gr.dart';
import 'package:disastron/shared/about/disastron_about.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:svg_flutter/svg_flutter.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _starsController;
  String? _versionLabel;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    PackageInfo.fromPlatform().then((PackageInfo info) {
      if (!mounted) return;
      setState(() {
        _packageInfo = info;
        _versionLabel = info.buildNumber.isEmpty
            ? info.version
            : '${info.version}+${info.buildNumber}';
      });
    });
  }

  @override
  void dispose() {
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Map<String, ToolPlacementFlags>> placementsAsync = ref
        .watch(toolPlacementsProvider);
    final AsyncValue<WikiPack> wikiAsync = ref.watch(wikiPackProvider);

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
          ...placementsAsync.when(
            data: (Map<String, ToolPlacementFlags> placements) {
              return wikiAsync.when(
                data: (WikiPack wikiPack) =>
                    _drawerShortcutTiles(context, placements, wikiPack),
                loading: () => <Widget>[],
                error: (_, _) => <Widget>[],
              );
            },
            loading: () => <Widget>[],
            error: (_, _) => <Widget>[],
          ),
          ..._drawerConfigurationTiles(context),
          if (_versionLabel != null) ...<Widget>[
            const SizedBox(height: 24),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  _versionLabel!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _drawerShortcutTiles(
    BuildContext context,
    Map<String, ToolPlacementFlags> placements,
    WikiPack wikiPack,
  ) {
    final List<Widget> tiles = <Widget>[];
    for (final String toolId in AppToolCatalog.idsForSurface(
      placements,
      AppToolSurface.drawer,
    )) {
      tiles.add(_shortcutTile(context, toolId, wikiPack));
    }
    if (tiles.isNotEmpty) {
      tiles.add(const Divider(height: 1));
    }
    return tiles;
  }

  List<Widget> _drawerConfigurationTiles(BuildContext context) {
    return <Widget>[
      ListTile(
        leading: const Icon(Icons.settings_outlined),
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
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text('drawer_about'.tr()),
        onTap: () async {
          Navigator.pop(context);
          final PackageInfo info =
              _packageInfo ?? await PackageInfo.fromPlatform();
          if (!context.mounted) {
            return;
          }
          await showDisastronAbout(context, packageInfo: info);
        },
      ),
    ];
  }

  Widget _shortcutTile(BuildContext context, String toolId, WikiPack wikiPack) {
    final AppToolDefinition def = AppToolCatalog.definitionFor(toolId);
    final ToolLayoutLabels labels = labelsForTool(toolId, wikiPack: wikiPack);
    return ListTile(
      leading: Icon(def.icon),
      title: Text(labels.title),
      subtitle: labels.subtitle != null ? Text(labels.subtitle!) : null,
      onTap: () async {
        Navigator.pop(context);
        if (!context.mounted) {
          return;
        }
        await openAppTool(context, ref, toolId);
      },
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
