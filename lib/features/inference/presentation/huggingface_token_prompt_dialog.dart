import 'package:disastron/features/inference/presentation/widgets/hugging_face_token_input.dart';
import 'package:flutter/material.dart';

/// Shown when a Hugging Face download is started without a stored token.
/// Returns trimmed token on Continue; null if cancelled.
Future<String?> showHuggingFaceTokenPasteDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) =>
        const _HuggingFaceTokenPasteDialog(),
  );
}

class _HuggingFaceTokenPasteDialog extends StatefulWidget {
  const _HuggingFaceTokenPasteDialog();

  @override
  State<_HuggingFaceTokenPasteDialog> createState() =>
      _HuggingFaceTokenPasteDialogState();
}

class _HuggingFaceTokenPasteDialogState
    extends State<_HuggingFaceTokenPasteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hugging Face token'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Downloads from Hugging Face need a read token. '
              'Create one at huggingface.co/settings/tokens',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            HuggingFaceTokenInput(
              controller: _controller,
              labelText: 'Paste hf_… token',
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final String t = _controller.text.trim();
            if (t.isEmpty) {
              return;
            }
            Navigator.of(context).pop(t);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
