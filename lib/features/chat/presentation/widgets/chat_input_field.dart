import 'dart:async';
import 'dart:typed_data';

import 'package:disastron/features/chat/presentation/chat_handlers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatInputField extends StatefulWidget {
  const ChatInputField({
    required this.onSubmitted,
    required this.isImageSupported,
    super.key,
  });

  final HumanMessageHandler onSubmitted;
  final bool isImageSupported;

  @override
  ChatInputFieldState createState() => ChatInputFieldState();
}

class ChatInputFieldState extends State<ChatInputField> {
  final TextEditingController _textController = TextEditingController();
  Uint8List? _pickedImageBytes;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (file == null || !mounted) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() => _pickedImageBytes = bytes);
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('chat_gallery'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickImage(ImageSource.gallery));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('chat_camera'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickImage(ImageSource.camera));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final ChatMessageDraft draft = ChatMessageDraft(
      text: _textController.text,
      imageBytes: _pickedImageBytes,
    );
    if (!draft.isNotEmpty) {
      return;
    }
    widget.onSubmitted(draft);
    _textController.clear();
    setState(() => _pickedImageBytes = null);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canSend = _textController.text.trim().isNotEmpty ||
        (_pickedImageBytes != null && _pickedImageBytes!.isNotEmpty);

    return IconTheme(
      data: IconThemeData(color: theme.colorScheme.onSurfaceVariant),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_pickedImageBytes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: <Widget>[
                        Image.memory(
                          _pickedImageBytes!,
                          height: 96,
                          width: 96,
                          fit: BoxFit.cover,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'chat_remove_image'.tr(),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _pickedImageBytes = null),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: widget.isImageSupported
                      ? 'chat_attach_image'.tr()
                      : 'chat_vision_model_required'.tr(),
                  icon: const Icon(Icons.image_outlined),
                  onPressed: widget.isImageSupported
                      ? () => unawaited(_showImageSourceSheet())
                      : null,
                ),
                Flexible(
                  child: TextField(
                    controller: _textController,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration.collapsed(
                      hintText: 'chat_hint'.tr(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: canSend ? _submit : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
