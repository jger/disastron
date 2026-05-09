import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';

typedef AssistantMessageHandler = Future<void> Function(Message message);

/// One user turn: optional text plus at most one image attachment.
class ChatMessageDraft {
  const ChatMessageDraft({this.text = '', this.imageBytes});

  final String text;
  final Uint8List? imageBytes;

  bool get isNotEmpty =>
      text.trim().isNotEmpty ||
      (imageBytes != null && imageBytes!.isNotEmpty);
}

typedef HumanMessageHandler = void Function(ChatMessageDraft draft);
