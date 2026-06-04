import 'package:disastron/features/inference/presentation/widgets/hugging_face_token_input.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Shown when a gated Hugging Face download starts without a stored token.
/// Returns trimmed token on Continue; null if cancelled.
Future<String?> showHuggingFaceTokenPasteDialog(
  BuildContext context, {
  String? modelTitle,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => _HuggingFaceTokenPasteDialog(
      modelTitle: modelTitle,
    ),
  );
}

class _HuggingFaceTokenPasteDialog extends StatefulWidget {
  const _HuggingFaceTokenPasteDialog({this.modelTitle});

  final String? modelTitle;

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
      title: Text('hf_token_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.modelTitle == null
                  ? 'hf_token_gated_generic'.tr()
                  : 'hf_token_gated_model'.tr(args: <String>[widget.modelTitle!]),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            HuggingFaceTokenInput(
              controller: _controller,
              labelText: 'hf_token_paste_label'.tr(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: () {
            final String t = _controller.text.trim();
            if (t.isEmpty) {
              return;
            }
            Navigator.of(context).pop(t);
          },
          child: Text('continue'.tr()),
        ),
      ],
    );
  }
}
