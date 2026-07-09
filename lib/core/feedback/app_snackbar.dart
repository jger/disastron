// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context, {
  required String message,
  SnackBarAction? action,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.showSnackBar(SnackBar(content: Text(message), action: action));
}
