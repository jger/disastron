import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:disastron/features/inference/presentation/widgets/hugging_face_token_input.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoraAddDialog extends ConsumerStatefulWidget {
  const LoraAddDialog({
    required this.modelEntryId,
    super.key,
  });

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
      setState(() => _errorMessage = 'lora_invalid_url'.tr());
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
      await ref.read(localGemmaModelProvider.notifier).installLoraFromNetwork(
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
          SnackBar(content: Text('lora_installed_url'.tr())),
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
          SnackBar(content: Text('lora_installed_file'.tr())),
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
      title: Text('lora_add'.tr()),
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
                    'lora_downloading'.tr(
                      namedArgs: <String, String>{'progress': '$_progress'},
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ] else ...<Widget>[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  Text(
                    'lora_importing'.tr(),
                    textAlign: TextAlign.center,
                  ),
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
                  tabs: <Tab>[
                    Tab(text: 'lora_url_tab'.tr()),
                    Tab(text: 'lora_file_tab'.tr()),
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
                            decoration: InputDecoration(
                              labelText: 'lora_add_url_label'.tr(),
                              hintText: 'model_url_hint'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          HuggingFaceTokenInput(
                            controller: _tokenController,
                            labelText: 'lora_add_token_label'.tr(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _labelController,
                            decoration: InputDecoration(
                              labelText: 'lora_add_display_label'.tr(),
                              hintText: 'lora_add_display_hint'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _downloadLora,
                            icon: const Icon(Icons.download),
                            label: Text('lora_download_install'.tr()),
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
                          Text(
                            'lora_pick_file_sub'.tr(),
                            textAlign: TextAlign.center,
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _pickLoraFile,
                            icon: const Icon(Icons.folder_open),
                            label: Text('lora_choose_file'.tr()),
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
