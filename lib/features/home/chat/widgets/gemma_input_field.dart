import 'dart:async';

import 'package:disastron/features/home/chat/chat_handlers.dart';
import 'package:disastron/features/home/chat/service/gemma_service.dart';
import 'package:disastron/features/home/chat/widgets/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class GemmaInputField extends StatefulWidget {
  const GemmaInputField({
    required this.userMessage,
    required this.streamHandled,
    required this.gemmaService,
    super.key,
  });

  final Message userMessage;
  final GemmaLocalService gemmaService;
  final AssistantMessageHandler streamHandled;

  @override
  GemmaInputFieldState createState() => GemmaInputFieldState();
}

class GemmaInputFieldState extends State<GemmaInputField> {
  StreamSubscription<ModelResponse>? _subscription;
  Message _message = Message.text(text: '');

  @override
  void initState() {
    super.initState();
    unawaited(_processMessages());
  }

  Future<void> _processMessages() async {
    _subscription = widget.gemmaService
        .processMessageAsync(widget.userMessage)
        .listen(
      (ModelResponse response) {
        if (response is TextResponse) {
          setState(() {
            _message = Message.text(
              text: '${_message.text}${response.token}',
            );
          });
        }
      },
      onDone: () async {
        await widget.streamHandled(_message);
      },
      onError: (Object e, StackTrace st) async {
        setState(() {
          _message = Message.text(
            text: '${_message.text}\n[Error: $e]',
          );
        });
        await widget.streamHandled(_message);
      },
    );
  }

  @override
  void dispose() {
    final Future<void>? cancelFuture = _subscription?.cancel();
    if (cancelFuture != null) {
      unawaited(cancelFuture);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ChatMessageWidget(message: _message),
    );
  }
}
