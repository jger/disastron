// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/shared/widgets/app_app_bar.dart';
import 'package:disastron/shared/widgets/app_drawer.dart';
import 'package:flutter/material.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    required this.body,
    required this.title,
    this.bottomNavigationBar,
    this.showAppBar = true,
    this.floatingActionButton,
    super.key,
  });

  final Widget body;
  final String title;
  final Widget? bottomNavigationBar;
  final bool showAppBar;
  final Widget? floatingActionButton;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  @override
  Widget build(BuildContext context) {
    // final User? user = FirebaseAuth.instance.currentUser;
    // if (user == null) {
    //   log('No user', name: '🏗️ AppScaffold');
    //   return const AppIndicator();
    // }
    return Scaffold(
      appBar: widget.showAppBar ? AppAppBar() : null,
      // drawer: const AppDrawer(),
      body: widget.body,
      bottomNavigationBar: widget.bottomNavigationBar,
      floatingActionButton: widget.floatingActionButton,
      drawer: const AppDrawer(),
    );
  }
}
