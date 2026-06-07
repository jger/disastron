// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/chat/presentation/chat_reset_provider.dart';
import 'package:disastron/features/home_shell/presentation/home_tab_index_provider.dart';
import 'package:disastron/features/wiki/presentation/wiki_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:svg_flutter/svg_flutter.dart';

class AppAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const AppAppBar({super.key});

  @override
  ConsumerState<AppAppBar> createState() => _AppAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppAppBarState extends ConsumerState<AppAppBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(homeBottomNavIndexProvider);
    final searchActive = ref.watch(wikiSearchActiveProvider);
    final resetCallback = ref.watch(chatResetProvider);
    final fg = Theme.of(context).appBarTheme.foregroundColor ??
        Theme.of(context).colorScheme.onSurface;

    final bool isWikiTab = selectedTab == 3;

    // Keep text field in sync with provider if changed externally (e.g. cleared)
    ref
      ..listen<String>(wikiSearchQueryProvider, (prev, next) {
        if (next != _searchController.text) {
          _searchController.text = next;
        }
      })

      // Reset search active and query when tab changes away from wiki
      ..listen<int>(homeBottomNavIndexProvider, (prev, next) {
        if (next != 3 && searchActive) {
          ref.read(wikiSearchActiveProvider.notifier).state = false;
          ref.read(wikiSearchQueryProvider.notifier).state = '';
          _searchController.clear();
        }
      });

    if (isWikiTab && searchActive) {
      return AppBar(
        elevation: 6,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(wikiSearchActiveProvider.notifier).state = false;
            ref.read(wikiSearchQueryProvider.notifier).state = '';
            _searchController.clear();
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'wiki_search_hint'.tr(),
            border: InputBorder.none,
          ),
          style: TextStyle(
            color: fg,
            fontSize: 18,
          ),
          onChanged: (text) {
            ref.read(wikiSearchQueryProvider.notifier).state = text;
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                ref.read(wikiSearchQueryProvider.notifier).state = '';
              },
            ),
        ],
      );
    }

    return AppBar(
      elevation: 6,
      centerTitle: true,
      title: SvgPicture.asset(
        'assets/images/logo-top-bw.svg',
        height: 22,
        colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
        semanticsLabel: 'Disastron',
      ),
      actions: [
        if (isWikiTab) ...[
          IconButton(
            tooltip: 'wiki_search_hint'.tr(),
            icon: const Icon(Icons.search),
            onPressed: () {
              ref.read(wikiSearchActiveProvider.notifier).state = true;
            },
          ),
        ],
        if (selectedTab == 2 && resetCallback != null) ...[
          IconButton(
            tooltip: 'Reset chat',
            icon: const Icon(Icons.restart_alt),
            onPressed: resetCallback,
          ),
        ],
      ],
    );
  }
}
