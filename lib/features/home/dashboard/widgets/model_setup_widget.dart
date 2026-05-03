import 'dart:async';

import 'package:disastron/app/widgets/appearance_dropdown.dart';
import 'package:disastron/features/home/model/active_inference_model_summary.dart';
import 'package:disastron/features/home/model/huggingface_token_provider.dart';
import 'package:disastron/features/home/model/local_gemma_model_provider.dart';
import 'package:disastron/features/home/model/model_network_install.dart';
import 'package:disastron/features/home/model/predefined_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ModelType _urlInstallModelType = ModelType.qwen;

  @override
  void initState() {
    super.initState();
    _installTabController = TabController(length: 3, vsync: this);
    _urlController = TextEditingController(
      text: kPredefinedInferenceModels.first.url,
    );
    _tokenController = TextEditingController();
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
    if (!await confirmLargeDownloadIfNotLikelyUnmetered(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final ModelFileType fileType = modelFileTypeForUrl(url);
    await ref.read(localGemmaModelProvider.notifier).installFromNetwork(
          url,
          modelType: _urlInstallModelType,
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
    if (!await confirmLargeDownloadIfNotLikelyUnmetered(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    await ref.read(localGemmaModelProvider.notifier).installFromNetwork(
          model.url,
          modelType: model.modelType,
          fileType: model.fileType,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocalGemmaModelUi>(localGemmaModelProvider, (LocalGemmaModelUi? previous, LocalGemmaModelUi next) {
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
        Text('Offline model', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
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
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircularProgressIndicator(value: ui.progress > 0 ? ui.progress / 100 : null),
            const SizedBox(height: 16),
            Text('Installing… ${ui.progress}%'),
          ],
        );
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
            SelectableText(ui.errorMessage ?? 'Unknown error'),
            const SizedBox(height: 24),
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
            Icon(Icons.cloud_off_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
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
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
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

  Widget _installedPanel(BuildContext context) {
    final ActiveInferenceModelSummary? summary = readActiveInferenceSummary();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 28),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          label: const Text('Change model'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
          },
          child: const Text('Refresh status'),
        ),
      ],
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
                return _urlTabBody(context, tokenAsync);
            }
          },
        ),
      ],
    );
  }

  Widget _presetTabBody(
    BuildContext context,
    AsyncValue<String?> tokenAsync,
  ) {
    final List<PredefinedInferenceModel> qwenModels = kPredefinedInferenceModels
        .where(
          (PredefinedInferenceModel m) =>
              !inferenceModelTypeUsesHuggingFaceToken(m.modelType),
        )
        .toList();
    final List<PredefinedInferenceModel> gemmaModels = kPredefinedInferenceModels
        .where(
          (PredefinedInferenceModel m) =>
              inferenceModelTypeUsesHuggingFaceToken(m.modelType),
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Qwen presets are public — no Hugging Face token. '
              'Gemma presets may need a token for gated files.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Qwen',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ...qwenModels.map(
              (PredefinedInferenceModel m) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(m.title),
                  subtitle: Text(m.description),
                  trailing: const Icon(Icons.download),
                  onTap: () => _installPreset(m),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 24),
            Text(
              'Gemma',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            const SelectableText(
              'Read token: https://huggingface.co/settings/tokens',
            ),
            const SizedBox(height: 8),
            tokenAsync.when(
              data: (String? saved) {
                if (saved != null && saved.isNotEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('A Hugging Face token is saved.'),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (Object error, StackTrace stackTrace) => const SizedBox.shrink(),
            ),
            TextField(
              controller: _tokenController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'hf_…',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: _saveToken,
                  child: const Text('Save token'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _clearToken,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...gemmaModels.map(
              (PredefinedInferenceModel m) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(m.title),
                  subtitle: Text(m.description),
                  trailing: const Icon(Icons.download),
                  onTap: () => _installPreset(m),
                ),
              ),
            ),
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
              'Pick a .task, .bin, .litertlm, or .tflite file you copied to this device.',
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

  Widget _urlTabBody(
    BuildContext context,
    AsyncValue<String?> tokenAsync,
  ) {
    final bool showToken =
        inferenceModelTypeUsesHuggingFaceToken(_urlInstallModelType);
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
            Text(
              'Model family for this URL',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Qwen 2.5'),
                  selected: _urlInstallModelType == ModelType.qwen,
                  onSelected: (bool v) {
                    if (v) {
                      setState(() => _urlInstallModelType = ModelType.qwen);
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Qwen3'),
                  selected: _urlInstallModelType == ModelType.qwen3,
                  onSelected: (bool v) {
                    if (v) {
                      setState(() => _urlInstallModelType = ModelType.qwen3);
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Gemma'),
                  selected: _urlInstallModelType == ModelType.gemmaIt,
                  onSelected: (bool v) {
                    if (v) {
                      setState(() => _urlInstallModelType = ModelType.gemmaIt);
                    }
                  },
                ),
              ],
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
            if (showToken) ...<Widget>[
              const SizedBox(height: 12),
              const SelectableText(
                'Read token: https://huggingface.co/settings/tokens',
              ),
              const SizedBox(height: 8),
              tokenAsync.when(
                data: (String? saved) {
                  if (saved != null && saved.isNotEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('A Hugging Face token is saved.'),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (Object error, StackTrace stackTrace) => const SizedBox.shrink(),
              ),
              TextField(
                controller: _tokenController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'hf_…',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  FilledButton(
                    onPressed: _saveToken,
                    child: const Text('Save token'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _clearToken,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
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
