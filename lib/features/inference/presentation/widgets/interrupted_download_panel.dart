import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:disastron/features/inference/presentation/model_install_status_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resume or discard a network download interrupted by cancel, app kill, or network loss.
class InterruptedDownloadPanel extends ConsumerWidget {
  const InterruptedDownloadPanel({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LocalGemmaModelUi ui = ref.watch(localGemmaModelProvider);
    if (ui.phase != LocalGemmaPhase.downloadInterrupted) {
      return const SizedBox.shrink();
    }

    final InstallStatusCopy copy = interruptedDownloadStatusCopy(ui);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final LocalGemmaModel notifier = ref.read(localGemmaModelProvider.notifier);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.cloud_download,
                      color: scheme.onTertiaryContainer,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        copy.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.onTertiaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                if (copy.subtitle != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    copy.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: notifier.discardPendingDownload,
                      child: const Text('Discard'),
                    ),
                    FilledButton(
                      onPressed: notifier.resumePendingNetworkInstall,
                      child: const Text('Resume download'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(Icons.cloud_download, size: 48, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          copy.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (copy.subtitle != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            copy.subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: notifier.resumePendingNetworkInstall,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Resume download'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: notifier.discardPendingDownload,
          child: const Text('Discard partial download'),
        ),
      ],
    );
  }
}
