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
