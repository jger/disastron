// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:svg_flutter/svg_flutter.dart';

class AppAppBar extends AppBar {
  AppAppBar({
    super.key,
  }) : super(
          elevation: 6,
          centerTitle: true,
          title: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              // final User? user = FirebaseAuth.instance.currentUser;
              // if (user == null) {
              //   return const SizedBox();
              // }
              final Color fg = Theme.of(context).appBarTheme.foregroundColor ??
                  Theme.of(context).colorScheme.onSurface;
              return SvgPicture.asset(
                'assets/images/logo-top-bw.svg',
                height: 22,
                colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                semanticsLabel: 'Disastron',
              );
            },
          ),
          actions: const [],
        );
}
