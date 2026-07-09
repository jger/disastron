// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/core/feedback/app_snackbar.dart';
import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:disastron/features/inference/presentation/model_install_status_copy.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Layout variants for the shared offline-model install progress UI.
enum ModelInstallProgressVariant {
  /// Dashboard banner (surface container, full width).
  dashboardBanner,

  /// Model setup tab body (centered column).
  setupCentered,
}

/// Progress, status copy, and cancel while a model install is in flight.
class ModelInstallProgressPanel extends ConsumerWidget {
  const ModelInstallProgressPanel({required this.variant, super.key});

  final ModelInstallProgressVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LocalGemmaModelUi ui = ref.watch(localGemmaModelProvider);
    if (ui.phase != LocalGemmaPhase.installing) {
      return const SizedBox.shrink();
    }
    final InstallStatusCopy status = modelInstallStatusCopy(ui);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    void onCancel() {
      ref.read(localGemmaModelProvider.notifier).requestInstallCancel();
      showAppSnackBar(context, message: 'snack_cancelled'.tr());
    }

    switch (variant) {
      case ModelInstallProgressVariant.dashboardBanner:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _dashboardColumn(context, scheme, ui, status, onCancel),
            ),
          ),
        );
      case ModelInstallProgressVariant.setupCentered:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(
                value: ui.progress > 0 ? ui.progress / 100 : null,
                minHeight: 8,
              ),
            ),
            if (ui.progress > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '${ui.progress}%',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              status.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (status.subtitle != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                status.subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 24),
            TextButton(onPressed: onCancel, child: Text('cancel'.tr())),
          ],
        );
    }
  }

  Widget _dashboardColumn(
    BuildContext context,
    ColorScheme scheme,
    LocalGemmaModelUi ui,
    InstallStatusCopy status,
    VoidCallback onCancel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.downloading, color: scheme.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (ui.progress > 0 && ui.progress < 100)
              Text(
                '${ui.progress}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (status.subtitle != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            status.subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: ui.progress > 0 ? ui.progress / 100.0 : null,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onCancel, child: Text('cancel'.tr())),
        ),
      ],
    );
  }
}
