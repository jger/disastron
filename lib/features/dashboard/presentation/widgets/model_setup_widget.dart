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
import 'package:easy_localization/easy_localization.dart';
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
        SnackBar(content: Text('model_hf_token_saved'.tr())),
      );
    }
  }

  Future<void> _clearToken() async {
    await ref.read(huggingfaceTokenProvider.notifier).clear();
    if (mounted) {
      _tokenController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('model_token_cleared'.tr())),
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
          SnackBar(content: Text('model_ready_snack'.tr())),
        );
      }
    });

    final LocalGemmaModelUi ui = ref.watch(localGemmaModelProvider);
    final AsyncValue<String?> tokenAsync = ref.watch(huggingfaceTokenProvider);

    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showAppearance) ...<Widget>[
          Text(
            'appearance'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                child: Text('cancel'.tr()),
              ),
            ],
          );
        }
        return _installedPanel(context);
      case LocalGemmaPhase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('error'.tr(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (ui.isGated403) ...<Widget>[
              Text(
                'model_gated_help'.tr(),
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
                        SnackBar(content: Text('model_browser_failed'.tr())),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text('model_open_page'.tr()),
                ),
              ],
              const SizedBox(height: 16),
              HuggingFaceTokenInput(
                controller: _tokenController,
                labelText: 'hf_token_paste_label'.tr(),
              ),
              const SizedBox(height: 12),
            ],
            SelectableText(ui.errorMessage ?? 'model_unknown_error'.tr()),
            if (_looksLikeInsufficientStorage(ui.errorMessage))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'model_low_storage'.tr(),
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
                    final String token = _tokenController.text.trim();
                    if (token.isNotEmpty) {
                      await ref
                          .read(huggingfaceTokenProvider.notifier)
                          .save(token);
                      if (mounted) {
                        _tokenController.clear();
                      }
                    }
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
                  label: Text('model_retry_download'.tr()),
                ),
              ),
            FilledButton(
              onPressed: () {
                _tokenController.clear();
                ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
              },
              child: Text('back'.tr()),
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
              'model_add_heading'.tr(),
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
              'model_none_installed'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'model_none_body'.tr(),
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
                'model_replace_warning'.tr(),
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
        title: Text('model_remove_title'.tr(args: <String>[e.displayTitle])),
        content: Text(
          e.importedFromPicker
              ? 'model_remove_picked'.tr()
              : 'model_remove_downloaded'.tr(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('remove'.tr()),
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
          title: Text('model_save_copy_title'.tr()),
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
                'model_save_preparing'.tr(),
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'model_save_background'.tr(),
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('close'.tr()),
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
          SnackBar(
            content: Text(
              'model_saved_copy'.tr(args: <String>[result.savedPath!]),
            ),
          ),
        );
      case ModelExportResultKind.cancelled:
        return;
      case ModelExportResultKind.failure:
      case ModelExportResultKind.unsupported:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'model_save_failed'.tr())),
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
      error: (Object e, StackTrace _) =>
          Text('model_list_error'.tr(args: <String>['$e'])),
      data: (ModelRegistrySnapshot snap) {
        final ActiveInferenceModelSummary? summary =
            readActiveInferenceSummary(registry: snap);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (snap.entries.isNotEmpty) ...<Widget>[
              Text(
                'model_installed_heading'.tr(),
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
                              'model_active_badge'.tr(),
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
                            child: Text('model_use'.tr()),
                          ),
                        IconButton(
                          tooltip: 'model_save_copy_tooltip'.tr(),
                          icon: const Icon(Icons.save_alt_outlined),
                          onPressed: () => _exportEntry(e),
                        ),
                        IconButton(
                          tooltip: 'model_remove_tooltip'.tr(),
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
                            'model_active_heading'.tr(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      summary?.label ?? 'model_installed_label'.tr(),
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
              label: Text('model_add_or_replace'.tr()),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                ref.invalidate(modelRegistrySnapshotProvider);
                ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
              },
              child: Text('model_refresh_status'.tr()),
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
          tabs: <Tab>[
            Tab(text: 'model_tab_preset'.tr()),
            Tab(text: 'model_tab_device'.tr()),
            Tab(text: 'model_tab_url'.tr()),
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
        saved ? 'model_hf_saved_optional'.tr() : 'model_hf_save_optional'.tr(),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        saved ? 'model_hf_gated_uses_saved'.tr() : 'model_hf_not_required'.tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      children: <Widget>[
        SelectableText(
          'model_hf_read_token'.tr(),
        ),
        const SizedBox(height: 8),
        if (saved) ...<Widget>[
          OutlinedButton(
            onPressed: _clearToken,
            child: Text('model_clear_saved_token'.tr()),
          ),
        ] else ...<Widget>[
          HuggingFaceTokenInput(controller: _tokenController),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveToken,
            child: Text('model_save_token'.tr()),
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
                  ? 'model_preset_tap_gated'.tr()
                  : gatedModels.isEmpty
                      ? 'model_preset_tap'.tr()
                      : 'model_preset_tap_public'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            _optionalHfTokenSection(context, tokenAsync),
            const SizedBox(height: 16),
            Text(
              'model_available_downloads'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (publicModels.isNotEmpty) ...<Widget>[
              Text(
                'model_public_presets'.tr(),
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
                'model_gated_presets'.tr(),
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
              'model_pick_file_help'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _pickAndInstall,
              icon: const Icon(Icons.folder_open),
              label: Text('model_choose_file'.tr()),
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
              'model_url_help'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              maxLines: 3,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'model_url_hint'.tr(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _downloadFromUrl,
              icon: const Icon(Icons.download),
              label: Text('model_download_install'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
