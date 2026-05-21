// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/chat/presentation/widgets/chat_screen.dart';
import 'package:flutter/material.dart';

@RoutePage()
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: ChatScreen());
  }
}
