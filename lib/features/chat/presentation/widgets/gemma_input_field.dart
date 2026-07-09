import 'dart:async';

import 'package:disastron/features/chat/presentation/chat_handlers.dart';
import 'package:disastron/features/chat/presentation/service/gemma_service.dart';
import 'package:disastron/features/chat/presentation/widgets/chat_message.dart';
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
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_processMessages());
  }

  Future<void> _processMessages() async {
    setState(() => _isGenerating = true);
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
            if (mounted) {
              setState(() => _isGenerating = false);
            }
            await widget.streamHandled(_message);
          },
          onError: (Object e, StackTrace st) async {
            if (mounted) {
              setState(() {
                _isGenerating = false;
                _message = Message.text(text: '${_message.text}\n[Error: $e]');
              });
            }
            await widget.streamHandled(_message);
          },
        );
  }

  Future<void> _stopGeneration() async {
    await _subscription?.cancel();
    _subscription = null;
    if (mounted) {
      setState(() => _isGenerating = false);
    }
    // Commit whatever was generated so far
    await widget.streamHandled(_message);
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
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.bottomRight,
      children: <Widget>[
        SingleChildScrollView(child: ChatMessageWidget(message: _message)),
        if (_isGenerating)
          Padding(
            padding: const EdgeInsets.only(bottom: 4, right: 4),
            child: IconButton(
              tooltip: 'Stop generating',
              icon: Icon(
                Icons.stop_circle_outlined,
                size: 28,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              onPressed: _stopGeneration,
              padding: const EdgeInsets.all(8),
            ),
          ),
      ],
    );
  }
}
