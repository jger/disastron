import 'package:disastron/features/inference/data/lora_registry_store.dart';
import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:disastron/features/inference/presentation/lora_add_dialog.dart';
import 'package:disastron/features/inference/presentation/lora_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoraManagerSheet extends ConsumerWidget {
  const LoraManagerSheet({
    required this.modelEntryId,
    required this.modelTitle,
    super.key,
  });

  final String modelEntryId;
  final String modelTitle;

  static void show(
    BuildContext context,
    String modelEntryId,
    String modelTitle,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => LoraManagerSheet(
        modelEntryId: modelEntryId,
        modelTitle: modelTitle,
      ),
    );
  }

  Future<void> _renameLora(
    BuildContext context,
    WidgetRef ref,
    InstalledLoraEntry entry,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: entry.displayLabel);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Rename LoRA Adapter'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Label',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (ok ?? false) {
      final String trimmed = controller.text.trim();
      if (trimmed.isNotEmpty) {
        await ref
            .read(localGemmaModelProvider.notifier)
            .updateLoraLabel(entry.id, trimmed);
      }
    }
    controller.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    InstalledLoraEntry entry,
  ) async {
    final bool? delete = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Remove LoRA Adapter?'),
        content: Text(
          'Delete "${entry.displayLabel}"? This removes the adapter and deletes its weight files from storage.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (delete ?? false) {
      await ref
          .read(localGemmaModelProvider.notifier)
          .removeLoraEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<LoraRegistrySnapshot> snapVal =
        ref.watch(loraRegistrySnapshotProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Sheet Drag Handle & Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'LoRA Adapters',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            modelTitle,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () =>
                          LoraAddDialog.show(context, modelEntryId),
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add LoRA Adapter',
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Body content
              Expanded(
                child: snapVal.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object err, StackTrace? stack) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error loading LoRA registry: $err'),
                  ),
                  data: (LoraRegistrySnapshot snap) {
                    final List<InstalledLoraEntry> modelLoras =
                        snap.entriesForModel(modelEntryId);
                    final String? activeLoraId =
                        snap.activeLoraIdPerModel[modelEntryId];

                    if (modelLoras.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.bolt_outlined,
                              size: 72,
                              color: scheme.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No LoRA Adapters',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Attach custom LoRA adapters to customize the behavior of this base model.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: modelLoras.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          // Header tile: Option to run with No LoRA (Base model)
                          final bool isBaseActive = activeLoraId == null;
                          return ListTile(
                            leading: Icon(
                              Icons.spa_outlined,
                              color: isBaseActive
                                  ? scheme.primary
                                  : scheme.outline,
                            ),
                            title: const Text('No LoRA (Use Base Model Only)'),
                            trailing: isBaseActive
                                ? Icon(
                                    Icons.check_circle,
                                    color: scheme.primary,
                                  )
                                : null,
                            selected: isBaseActive,
                            onTap: () {
                              ref
                                  .read(localGemmaModelProvider.notifier)
                                  .setActiveLora(null, modelEntryId);
                            },
                          );
                        }

                        final InstalledLoraEntry entry = modelLoras[index - 1];
                        final bool isActive = entry.id == activeLoraId;

                        return ListTile(
                          leading: Icon(
                            Icons.bolt,
                            color:
                                isActive ? Colors.amber[700] : scheme.outline,
                          ),
                          title: Text(
                            entry.displayLabel,
                            style: TextStyle(
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            entry.importedFromPicker
                                ? 'Local File'
                                : entry.sourceUrlOrPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Rename Label',
                                onPressed: () =>
                                    _renameLora(context, ref, entry),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete Adapter',
                                onPressed: () =>
                                    _confirmDelete(context, ref, entry),
                              ),
                              if (isActive)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                          selected: isActive,
                          onTap: () {
                            ref
                                .read(localGemmaModelProvider.notifier)
                                .setActiveLora(entry.id, modelEntryId);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
