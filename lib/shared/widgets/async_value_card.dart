/// ***************************************************************************
/// Copyright (c) 2026 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'package:disastron/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card wrapper for [AsyncValue] loading/error/data used by dashboard tiles.
class AsyncValueCard<T> extends StatelessWidget {
  const AsyncValueCard({
    required this.value,
    required this.title,
    required this.dataBuilder,
    super.key,
    this.loadingLabel,
    this.padding = AppSpacing.screenPadding,
  });

  final AsyncValue<T> value;
  final String title;
  final Widget Function(BuildContext context, T data) dataBuilder;
  final String? loadingLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: value.when(
          skipLoadingOnReload: true,
          data: (T data) => dataBuilder(context, data),
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.gapMd),
              const LinearProgressIndicator(),
              if (loadingLabel != null) ...<Widget>[
                const SizedBox(height: AppSpacing.gapSm),
                Text(loadingLabel!),
              ],
            ],
          ),
          error: (Object e, StackTrace _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.gapSm),
              Text(
                '$e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
