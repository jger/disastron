/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'package:flutter/material.dart';

/// Shared layout tokens to avoid magic numbers across cards and screens.
abstract final class AppSpacing {
  AppSpacing._();

  static const double cardRadius = 12;
  static const EdgeInsets screenPadding = EdgeInsets.all(16);
  static const double gapSm = 8;
  static const double gapMd = 12;
  static const double gapLg = 16;
}
