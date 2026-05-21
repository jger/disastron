import 'dart:async';

import 'package:disastron/app/widgets/appearance_dropdown.dart';
import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:disastron/features/inference/domain/predefined_models.dart';
import 'package:disastron/features/inference/presentation/active_inference_model_summary.dart';
import 'package:disastron/features/inference/presentation/huggingface_token_provider.dart';
import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:disastron/features/inference/presentation/model_file_export.dart';
import 'package:disastron/features/inference/presentation/model_install_flow_coordinator.dart';
import 'package:disastron/features/inference/presentation/model_registry_provider.dart';
import 'package:disastron/features/inference/presentation/widgets/hugging_face_token_input.dart';
import 'package:disastron/features/inference/presentation/widgets/interrupted_download_panel.dart';
import 'package:disastron/features/inference/presentation/widgets/model_install_progress_panel.dart';
import 'package:disastron/features/inference/presentation/widgets/preset_download_metadata.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

bool hasPersistedHfToken(AsyncValue<String?> tokenAsync) {
  return tokenAsync.maybeWhen(
    data: (String? v) => v != null && v.trim().isNotEmpty,
    orElse: () => false,
  );
}

bool _looksLikeInsufficientStorage(String? message) {
  if (message == null || message.isEmpty) {
    return false;
  }
  final String lower = message.toLowerCase();
  return lower.contains('enospc') ||
      lower.contains('no space left') ||
      lower.contains('not enough space') ||
      lower.contains('disk full') ||
      lower.contains('storage full') ||
      lower.contains('sqlite_full');
}

class ModelSetupWidget extends ConsumerStatefulWidget {
  const ModelSetupWidget({
    super.key,
    this.showAppearance = true,
    this.wrapInScrollView = true,
  });

  /// When embedded in another scroll view (e.g. dashboard), set false.
  final bool wrapInScrollView;

  /// Theme controls live in dashboard config when false.
  final bool showAppearance;

  @override
  ConsumerState<ModelSetupWidget> createState() => _ModelSetupWidgetState();
}

class _ModelSetupWidgetState extends ConsumerState<ModelSetupWidget>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  late final TabController _installTabController;
  bool _showReplaceFlow = false;

  @override
  void initState() {
    super.initState();
    _installTabController = TabController(length: 3, vsync: this);
    _urlController = TextEditingController(
      text: kPredefinedInferenceModels.first.url,
    );
    _tokenController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref.read(localGemmaModelProvider.notifier).refreshPendingDownload(),
      );
    });
  }

  @override
  void dispose() {
    _installTabController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _pickAndInstall() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['task', 'bin', 'litertlm', 'tflite'],
    );
    final String? path = result?.files.single.path;
    if (path == null || !mounted) {
      return;
    }
    await ref.read(localGemmaModelProvider.notifier).installFromFile(path);
  }

  Future<void> _downloadFromUrl() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    final bool ok = await coordinateUrlInstallPreflight(
      context: context,
      ref: ref,
    );
    if (!ok || !mounted) {
      return;
    }
    final ModelFileType fileType = modelFileTypeForUrl(url);
    await ref.read(localGemmaModelProvider.notifier).installFromNetwork(
          url,
          modelType: modelTypeForInferenceUrl(url),
          fileType: fileType,
        );
  }

  Future<void> _saveToken() async {
    final String t = _tokenController.text.trim();
    if (t.isEmpty) {
      return;
    }
    await ref.read(huggingfaceTokenProvider.notifier).save(t);
    if (mounted) {
      _tokenController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hugging Face token saved')),
      );
    }
  }

  Future<void> _clearToken() async {
    await ref.read(huggingfaceTokenProvider.notifier).clear();
    if (mounted) {
      _tokenController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token cleared')),
      );
    }
  }

  Future<void> _installPreset(PredefinedInferenceModel model) async {
    setState(() {
      _urlController.text = model.url;
    });
    if (!mounted) {
      return;
    }
    final bool ok = await coordinateInferenceNetworkInstallPreflight(
      context: context,
      ref: ref,
      model: model,
    );
    if (!ok || !mounted) {
      return;
    }
    await ref
        .read(localGemmaModelProvider.notifier)
        .installPresetById(model.id);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocalGemmaModelUi>(localGemmaModelProvider,
        (LocalGemmaModelUi? previous, LocalGemmaModelUi next) {
      if (next.phase == LocalGemmaPhase.ready &&
          (previous == null || previous.phase != LocalGemmaPhase.ready)) {
        if (mounted) {
          setState(() => _showReplaceFlow = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model ready. Open Chat to talk.')),
        );
      }
    });

    final LocalGemmaModelUi ui = ref.watch(localGemmaModelProvider);
    final AsyncValue<String?> tokenAsync = ref.watch(huggingfaceTokenProvider);

    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showAppearance) ...<Widget>[
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const AppearanceDropdown(),
          const SizedBox(height: 24),
        ],
        _body(context, ui, tokenAsync),
      ],
    );

    if (widget.wrapInScrollView) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: column,
      );
    }
    return column;
  }

  Widget _body(
    BuildContext context,
    LocalGemmaModelUi ui,
    AsyncValue<String?> tokenAsync,
  ) {
    switch (ui.phase) {
      case LocalGemmaPhase.installing:
        return const ModelInstallProgressPanel(
          variant: ModelInstallProgressVariant.setupCentered,
        );
      case LocalGemmaPhase.downloadInterrupted:
        return const InterruptedDownloadPanel();
      case LocalGemmaPhase.ready:
        if (_showReplaceFlow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _replaceBanner(context),
              const SizedBox(height: 16),
              _installationOptions(context, tokenAsync),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() => _showReplaceFlow = false),
                child: const Text('Cancel'),
              ),
            ],
          );
        }
        return _installedPanel(context);
      case LocalGemmaPhase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Error', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (ui.isGated403) ...<Widget>[
              Text(
                'This model is gated on Hugging Face. Open the model page, '
                'sign in, and accept the licence (Google terms), then retry.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (ui.gatedModelPageUrl != null) ...<Widget>[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final Uri uri = Uri.parse(ui.gatedModelPageUrl!);
                    final bool ok = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open browser')),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open model page'),
                ),
              ],
              const SizedBox(height: 12),
            ],
            SelectableText(ui.errorMessage ?? 'Unknown error'),
            if (_looksLikeInsufficientStorage(ui.errorMessage))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Low storage often causes install failures. Free disk space and retry.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            const SizedBox(height: 24),
            if (ui.lastFailedDownloadUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.icon(
                  onPressed: () async {
                    final LocalGemmaModel notifier =
                        ref.read(localGemmaModelProvider.notifier);
                    await notifier.resumePendingNetworkInstall();
                    if (!context.mounted) {
                      return;
                    }
                    final LocalGemmaModelUi after =
                        ref.read(localGemmaModelProvider);
                    if (after.phase == LocalGemmaPhase.error &&
                        after.lastFailedDownloadUrl != null) {
                      await notifier.installFromNetwork(
                        after.lastFailedDownloadUrl!,
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry download'),
                ),
              ),
            FilledButton(
              onPressed: () {
                ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
              },
              child: const Text('Back'),
            ),
          ],
        );
      case LocalGemmaPhase.notInstalled:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _emptyStateHeader(context),
            const SizedBox(height: 20),
            Text(
              'Add a model:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _installationOptions(context, tokenAsync),
          ],
        );
    }
  }

  Widget _emptyStateHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No offline model installed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Chat runs on-device. Install a compatible model file before you can use Chat.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _replaceBanner(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Installing another model replaces the current one.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onUseEntry(InstalledModelEntry e) async {
    await ref
        .read(localGemmaModelProvider.notifier)
        .switchToRegistryEntry(e.id);
  }

  Future<void> _confirmRemoveEntry(InstalledModelEntry e) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Remove ${e.displayTitle}?'),
        content: Text(
          e.importedFromPicker
              ? 'Removes this model from the app. The file you picked stays on disk.'
              : 'Deletes downloaded model data from app storage to free space.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if ((ok ?? false) && mounted) {
      await ref
          .read(localGemmaModelProvider.notifier)
          .removeRegistryEntry(e.id);
    }
  }

  Future<void> _exportEntry(InstalledModelEntry e) async {
    if (!mounted) {
      return;
    }
    bool dialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Save copy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LinearProgressIndicator(
                backgroundColor:
                    Theme.of(ctx).colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 12),
              Text(
                'Preparing file…',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'You can close this window; saving continues in the background.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ).then((_) {
        dialogVisible = false;
      }),
    );
    final ModelExportResult result = await ref
        .read(localGemmaModelProvider.notifier)
        .exportRegistryEntryToUserLocation(e.id);
    if (mounted && dialogVisible) {
      Navigator.of(context).pop();
    }
    if (!mounted) {
      return;
    }
    switch (result.kind) {
      case ModelExportResultKind.success:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved copy: ${result.savedPath}')),
        );
      case ModelExportResultKind.cancelled:
        return;
      case ModelExportResultKind.failure:
      case ModelExportResultKind.unsupported:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Could not save copy')),
        );
    }
  }

  Widget _installedPanel(BuildContext context) {
    final AsyncValue<ModelRegistrySnapshot> reg =
        ref.watch(modelRegistrySnapshotProvider);

    return reg.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (Object e, StackTrace _) => Text('Model list error: $e'),
      data: (ModelRegistrySnapshot snap) {
        final ActiveInferenceModelSummary? summary =
            readActiveInferenceSummary(registry: snap);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (snap.entries.isNotEmpty) ...<Widget>[
              Text(
                'Installed models',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              ...snap.entries.map(
                (InstalledModelEntry e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(e.displayTitle),
                    subtitle: Text(
                      '${e.modelType.name} · ${e.fileType.name}'
                      '${e.presetId != null ? ' · preset' : ''}',
                    ),
                    isThreeLine: false,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (snap.activeEntryId == e.id)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              'Active',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () => _onUseEntry(e),
                            child: const Text('Use'),
                          ),
                        IconButton(
                          tooltip: 'Save copy',
                          icon: const Icon(Icons.save_alt_outlined),
                          onPressed: () => _exportEntry(e),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmRemoveEntry(e),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Active model',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      summary?.label ?? 'Installed',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (summary != null) ...<Widget>[
                      const SizedBox(height: 6),
                      SelectableText(
                        summary.detailLine,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => setState(() => _showReplaceFlow = true),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Add or replace model'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                ref.invalidate(modelRegistrySnapshotProvider);
                ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
              },
              child: const Text('Refresh status'),
            ),
          ],
        );
      },
    );
  }

  Widget _installationOptions(
    BuildContext context,
    AsyncValue<String?> tokenAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TabBar(
          controller: _installTabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const <Tab>[
            Tab(text: 'Download preset'),
            Tab(text: 'This device'),
            Tab(text: 'From URL'),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _installTabController,
          builder: (BuildContext context, Widget? _) {
            switch (_installTabController.index) {
              case 0:
                return _presetTabBody(context, tokenAsync);
              case 1:
                return _importTabBody(context);
              default:
                return _urlTabBody(context);
            }
          },
        ),
      ],
    );
  }

  /// Optional pre-save; gated downloads prompt via dialog when no token is stored.
  Widget _optionalHfTokenSection(
    BuildContext context,
    AsyncValue<String?> tokenAsync,
  ) {
    final bool saved = hasPersistedHfToken(tokenAsync);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        saved
            ? 'Hugging Face token saved (optional)'
            : 'Save Hugging Face token ahead of time (optional)',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        saved
            ? 'Gated downloads use the saved token.'
            : 'Not required until you download a gated preset.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      children: <Widget>[
        const SelectableText(
          'Read token: https://huggingface.co/settings/tokens',
        ),
        const SizedBox(height: 8),
        if (saved) ...<Widget>[
          OutlinedButton(
            onPressed: _clearToken,
            child: const Text('Clear saved token'),
          ),
        ] else ...<Widget>[
          HuggingFaceTokenInput(controller: _tokenController),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveToken,
            child: const Text('Save token'),
          ),
        ],
      ],
    );
  }

  Widget _presetTabBody(
    BuildContext context,
    AsyncValue<String?> tokenAsync,
  ) {
    final List<PredefinedInferenceModel> publicModels =
        kPredefinedInferenceModels
            .where((PredefinedInferenceModel m) => !m.requiresHuggingFaceToken)
            .toList();
    final List<PredefinedInferenceModel> gatedModels =
        kPredefinedInferenceModels
            .where((PredefinedInferenceModel m) => m.requiresHuggingFaceToken)
            .toList();

    Widget presetTiles(Iterable<PredefinedInferenceModel> models) {
      return Column(
        children: <Widget>[
          ...models.map(
            (PredefinedInferenceModel m) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(m.title),
                subtitle: PresetDownloadMetadataSubtitle(model: m),
                isThreeLine: true,
                trailing: const Icon(Icons.download),
                onTap: () => _installPreset(m),
              ),
            ),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              publicModels.isEmpty
                  ? 'Tap a preset to download. Gated models ask for a Hugging Face read token when needed.'
                  : gatedModels.isEmpty
                      ? 'Tap a preset to download.'
                      : 'Public presets need no token. Gated presets ask for a Hugging Face read token when you tap download.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            _optionalHfTokenSection(context, tokenAsync),
            const SizedBox(height: 16),
            Text(
              'Available downloads',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (publicModels.isNotEmpty) ...<Widget>[
              Text(
                'Public presets',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              presetTiles(publicModels),
            ],
            if (gatedModels.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Gated on Hugging Face',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              presetTiles(gatedModels),
            ],
          ],
        ),
      ),
    );
  }

  Widget _importTabBody(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Pick a .task, .bin, .litertlm, or .tflite file (e.g. one you saved '
              'to Downloads from Installed models → Save copy).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _pickAndInstall,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose file'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _urlTabBody(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Paste a direct link to a model file.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'https://…/model.task',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _downloadFromUrl,
              icon: const Icon(Icons.download),
              label: const Text('Download & install'),
            ),
          ],
        ),
      ),
    );
  }
}
