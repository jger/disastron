import 'package:disastron/features/home/model/local_gemma_model_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default small Gemma 3 270M `.task` (mobile-friendly; user can change URL).
const String kDefaultModelDownloadUrl =
    'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task';

class ModelSetupWidget extends ConsumerStatefulWidget {
  const ModelSetupWidget({super.key});

  @override
  ConsumerState<ModelSetupWidget> createState() => _ModelSetupWidgetState();
}

class _ModelSetupWidgetState extends ConsumerState<ModelSetupWidget> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: kDefaultModelDownloadUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
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
    await ref.read(localGemmaModelProvider.notifier).installFromNetwork(url);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocalGemmaModelUi>(localGemmaModelProvider, (LocalGemmaModelUi? previous, LocalGemmaModelUi next) {
      if (next.phase == LocalGemmaPhase.ready &&
          (previous == null || previous.phase != LocalGemmaPhase.ready)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model ready. Open Messages to chat.')),
        );
      }
    });

    final LocalGemmaModelUi ui = ref.watch(localGemmaModelProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Offline model', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _body(context, ui),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, LocalGemmaModelUi ui) {
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text('Model installed and active.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
              },
              child: const Text('Refresh status'),
            ),
          ],
        );
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
            Text(
              'Disastron runs fully offline. Add a compatible model file to this device — '
              'import a file you copied (USB, AirDrop, Files) or download when you have network.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickAndInstall,
              icon: const Icon(Icons.folder_open),
              label: const Text('Import from device'),
            ),
            const SizedBox(height: 24),
            Text('Download from URL', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
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
        );
    }
  }
}
