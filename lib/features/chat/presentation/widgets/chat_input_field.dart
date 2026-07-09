import 'dart:async';

import 'package:disastron/core/feedback/app_snackbar.dart';
import 'package:disastron/features/chat/presentation/chat_handlers.dart';
import 'package:disastron/features/chat/presentation/widgets/camera_capture_page.dart';
import 'package:flutter/foundation.dart';
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
  final ImagePicker _picker = ImagePicker();
  Uint8List? _pickedImageBytes;

  static const String _unsupportedImageHint =
      'Image input needs a multimodal model (e.g. Gemma 3n / Gemma 4 preset).';

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLostImage());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Recovers a photo taken just before Android killed the process.
  ///
  /// While the camera/gallery intent is in the foreground this app is a cached
  /// background process, and a loaded multimodal model makes it the fattest
  /// target for the low-memory killer. Android then relaunches us and hands the
  /// file over here instead of returning it from [_pickImage]'s future, which
  /// never completes.
  Future<void> _restoreLostImage() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final LostDataResponse lost = await _picker.retrieveLostData();
    if (lost.isEmpty || !mounted) {
      return;
    }
    if (lost.exception != null) {
      showAppSnackBar(
        context,
        message: 'Could not restore the photo you took. Please try again.',
      );
      return;
    }
    final XFile? file = lost.file;
    if (file == null || lost.type != RetrieveType.image) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() => _pickedImageBytes = bytes);
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
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

  /// Captures in-process so the app never backgrounds and never becomes a
  /// low-memory-killer target while the model is loaded. See
  /// [CameraCapturePage]. Web keeps `image_picker`, which has no such problem.
  Future<void> _takePhoto() async {
    if (kIsWeb) {
      await _pickImage(ImageSource.camera);
      return;
    }
    final Uint8List? bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (BuildContext _) => const CameraCapturePage(),
      ),
    );
    if (bytes == null || !mounted) {
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
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickImage(ImageSource.gallery));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_takePhoto());
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
    final bool canSend =
        _textController.text.trim().isNotEmpty ||
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
                          tooltip: 'Remove image',
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
                      ? 'Attach image'
                      : _unsupportedImageHint,
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
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Send a message',
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
