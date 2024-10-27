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
import 'package:disastron/features/home/dashboard/dashboard_page.dart';
import 'package:disastron/features/home/messages/messages_page.dart';
import 'package:disastron/features/home/todos/todos_page.dart';
import 'package:disastron/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

@RoutePage()
class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PageController pageController = usePageController();
    final ValueNotifier<int> selectedIndex = useState(0);
    return AppScaffold(
      title: [
        'Dashboard',
        'Todos',
        'Messages',
      ][selectedIndex.value],
      body: PageView(
        controller: pageController,
        onPageChanged: (int index) {
          selectedIndex.value = index;
        },
        children: const <Widget>[
          DashboardPage(),
          TodosPage(),
          MessagesPage(),
        ],
      ),
      bottomNavigationBar: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          return NavigationBar(
            elevation: 2,

            onDestinationSelected: (int index) {
              selectedIndex.value = index;
              pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            },
            // indicatorColor: Theme.of(context).colorScheme.tertiaryContainer,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            selectedIndex: selectedIndex.value,
            destinations: const <Widget>[
              NavigationDestination(
                icon: Icon(Icons.computer_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_sharp),
                label: 'Todos',
              ),
              NavigationDestination(
                icon: Icon(Icons.messenger_sharp),
                label: 'Messages',
              ),
            ],
          );
        },
      ),
    );
  }
}
