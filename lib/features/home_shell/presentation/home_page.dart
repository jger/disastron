// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:auto_route/auto_route.dart';
import 'package:disastron/app/initial_language_dialog.dart';
import 'package:disastron/app/locale_provider.dart';
import 'package:disastron/app/terms_dialog.dart';
import 'package:disastron/app/web_pwa_notice_dialog.dart';
import 'package:disastron/features/chat/presentation/chat_page.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_page.dart';
import 'package:disastron/features/home_shell/presentation/home_tab_index_provider.dart';
import 'package:disastron/features/todos/presentation/todo_tab_badge_provider.dart';
import 'package:disastron/features/todos/presentation/todos_page.dart';
import 'package:disastron/features/wiki/presentation/wiki_page.dart';
import 'package:disastron/shared/widgets/app_scaffold.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

@RoutePage()
class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int selectedIndex = ref.watch(homeBottomNavIndexProvider);
    final int todoBadgeCount = ref.watch(todoTabBadgeProvider);
    final ObjectRef<bool> languageDialogScheduled = useRef(false);
    final ObjectRef<bool> termsDialogScheduled = useRef(false);
    final ObjectRef<bool> webPwaNoticeScheduled = useRef(false);
    final AsyncValue<AppLocaleState> localeAsync = ref.watch(appLocaleProvider);

    useEffect(() {
      final AppLocaleState? s = localeAsync.maybeWhen(
        data: (AppLocaleState x) => x,
        orElse: () => null,
      );
      if (s == null) {
        return null;
      }
      if (!s.initialChoiceDone && !languageDialogScheduled.value) {
        languageDialogScheduled.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!context.mounted) {
            return;
          }
          await showInitialLanguageDialog(
            context,
            ref,
          );
        });
      } else if (s.initialChoiceDone &&
          !s.termsAccepted &&
          !termsDialogScheduled.value) {
        termsDialogScheduled.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!context.mounted) {
            return;
          }
          await showTermsDialog(
            context,
            ref,
          );
        });
      } else if (kIsWeb &&
          s.initialChoiceDone &&
          s.termsAccepted &&
          !webPwaNoticeScheduled.value) {
        webPwaNoticeScheduled.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!context.mounted) {
            return;
          }
          await showWebPwaNoticeDialogIfNeeded(context);
        });
      }
      return null;
    }, <Object?>[
      localeAsync,
    ]);

    final String tabLocale = localeAsync.maybeWhen(
      data: (AppLocaleState s) => s.localeCode,
      orElse: () => '',
    );

    return AppScaffold(
      title: <String>[
        'nav_dashboard'.tr(),
        'nav_todos'.tr(),
        'nav_chat'.tr(),
        'nav_wiki'.tr(),
      ][selectedIndex],
      body: IndexedStack(
        index: selectedIndex,
        children: <Widget>[
          DashboardPage(key: ValueKey<String>('home_tab_d_$tabLocale')),
          TodosPage(key: ValueKey<String>('home_tab_t_$tabLocale')),
          MessagesPage(key: ValueKey<String>('home_tab_m_$tabLocale')),
          WikiPage(key: ValueKey<String>('home_tab_w_$tabLocale')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        elevation: 2,
        onDestinationSelected: (int index) {
          ref.read(homeBottomNavIndexProvider.notifier).state = index;
          if (index == 1) {
            ref.read(todoTabBadgeProvider.notifier).clear();
          }
        },
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        selectedIndex: selectedIndex,
        destinations: <Widget>[
          NavigationDestination(
            icon: const Icon(Icons.computer_rounded),
            label: 'nav_dashboard'.tr(),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: todoBadgeCount > 0,
              label: Text(
                todoBadgeCount > 99 ? '99+' : '$todoBadgeCount',
              ),
              child: const Icon(Icons.checklist_rounded),
            ),
            label: 'nav_todos'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.smart_toy_outlined),
            label: 'nav_chat'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            label: 'nav_wiki'.tr(),
          ),
        ],
      ),
    );
  }
}
