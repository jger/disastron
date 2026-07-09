import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:disastron/features/inference/presentation/widgets/hugging_face_token_input.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoraAddDialog extends ConsumerStatefulWidget {
  const LoraAddDialog({required this.modelEntryId, super.key});

  final String modelEntryId;

  static Future<void> show(BuildContext context, String modelEntryId) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => LoraAddDialog(modelEntryId: modelEntryId),
    );
  }

  @override
  ConsumerState<LoraAddDialog> createState() => _LoraAddDialogState();
}

class _LoraAddDialogState extends ConsumerState<LoraAddDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  late final TextEditingController _labelController;

  int? _progress;
  bool _isLoading = false;
  String? _errorMessage;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _urlController = TextEditingController();
    _tokenController = TextEditingController();
    _labelController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _labelController.dispose();
    _cancelToken?.cancel('Dialog disposed');
    super.dispose();
  }

  Future<void> _downloadLora() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid URL.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _progress = 0;
    });

    _cancelToken = CancelToken();

    try {
      final String? token = _tokenController.text.trim().isEmpty
          ? null
          : _tokenController.text.trim();
      await ref
          .read(localGemmaModelProvider.notifier)
          .installLoraFromNetwork(
            url,
            widget.modelEntryId,
            token: token,
            onProgress: (int p) {
              if (mounted) {
                setState(() => _progress = p);
              }
            },
            cancelToken: _cancelToken,
          );

      // Optionally rename if label is custom
      final String customLabel = _labelController.text.trim();
      if (customLabel.isNotEmpty) {
        final String loraEntryId = 'lora:${url.hashCode}';
        await ref
            .read(localGemmaModelProvider.notifier)
            .updateLoraLabel(loraEntryId, customLabel);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('LoRA adapter installed successfully.')),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _progress = null;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _pickLoraFile() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['bin', 'task', 'litertlm', 'tflite'],
      );

      final String? path = result?.files.single.path;
      if (path == null) {
        setState(() => _isLoading = false);
        return;
      }

      await ref
          .read(localGemmaModelProvider.notifier)
          .installLoraFromFile(path, widget.modelEntryId);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('LoRA adapter imported successfully.')),
        );
      }
    } on Object catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _onCancel() {
    _cancelToken?.cancel('User cancelled download');
    setState(() {
      _isLoading = false;
      _progress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Add LoRA Adapter'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_isLoading) ...<Widget>[
                const SizedBox(height: 16),
                if (_progress != null) ...<Widget>[
                  LinearProgressIndicator(value: _progress! / 100.0),
                  const SizedBox(height: 8),
                  Text(
                    'Downloading: $_progress%',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ] else ...<Widget>[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Text('Importing file...', textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                if (_progress != null)
                  TextButton.icon(
                    onPressed: _onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text('cancel'.tr()),
                  ),
              ] else ...<Widget>[
                TabBar(
                  controller: _tabController,
                  tabs: const <Tab>[
                    Tab(text: 'From URL'),
                    Tab(text: 'Pick File'),
                  ],
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  height: 300,
                  child: TabBarView(
                    controller: _tabController,
                    children: <Widget>[
                      // Tab 1: From URL
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              labelText: 'LoRA Download URL',
                              hintText: 'https://...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          HuggingFaceTokenInput(
                            controller: _tokenController,
                            labelText: 'HF Token (optional)',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _labelController,
                            decoration: const InputDecoration(
                              labelText: 'Display Label (optional)',
                              hintText: 'e.g. Fine-tuned LoRA',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _downloadLora,
                            icon: const Icon(Icons.download),
                            label: const Text('Download & Install'),
                          ),
                        ],
                      ),
                      // Tab 2: Pick File
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Icon(
                            Icons.file_open_outlined,
                            size: 64,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Select a local LoRA binary (.bin / .task / .litertlm) from your device storage.',
                            textAlign: TextAlign.center,
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _pickLoraFile,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Choose File'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: _isLoading
          ? null
          : <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('cancel'.tr()),
              ),
            ],
    );
  }
}
