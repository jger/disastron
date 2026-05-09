/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/home/chat/chat_page.dart';
import 'package:disastron/features/home/dashboard/dashboard_page.dart';
import 'package:disastron/features/home/home_tab_index_provider.dart';
import 'package:disastron/features/home/todos/todo_tab_badge_provider.dart';
import 'package:disastron/features/home/todos/todos_page.dart';
import 'package:disastron/features/home/wiki/wiki_page.dart';
import 'package:disastron/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

@RoutePage()
class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ValueNotifier<int> selectedIndex = useState(0);
    final int todoBadgeCount = ref.watch(todoTabBadgeProvider);
    return AppScaffold(
      title: [
        'Dashboard',
        'Todos',
        'Chat',
        'Wiki',
      ][selectedIndex.value],
      body: IndexedStack(
        index: selectedIndex.value,
        children: const <Widget>[
          DashboardPage(),
          TodosPage(),
          MessagesPage(),
          WikiPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        elevation: 2,
        onDestinationSelected: (int index) {
          ref.read(homeBottomNavIndexProvider.notifier).state = index;
          if (index == 1) {
            ref.read(todoTabBadgeProvider.notifier).clear();
          }
          selectedIndex.value = index;
        },
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        selectedIndex: selectedIndex.value,
        destinations: <Widget>[
          const NavigationDestination(
            icon: Icon(Icons.computer_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: todoBadgeCount > 0,
              label: Text(
                todoBadgeCount > 99 ? '99+' : '$todoBadgeCount',
              ),
              child: const Icon(Icons.checklist_rounded),
            ),
            label: 'Todos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            label: 'Chat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Wiki',
          ),
        ],
      ),
    );
  }
}
