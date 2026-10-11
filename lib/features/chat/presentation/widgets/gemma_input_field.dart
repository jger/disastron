import 'dart:async';

import 'package:disastron/features/chat/data/gemma_service.dart';
import 'package:disastron/features/chat/presentation/chat_handlers.dart';
import 'package:disastron/features/chat/presentation/widgets/chat_message.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';

class GemmaInputField extends StatefulWidget {
  const GemmaInputField({
    required this.userMessage,
    required this.streamHandled,
    required this.gemmaService,
    this.onChecklistToolCall,
    super.key,
  });

  final Message userMessage;
  final GemmaLocalService gemmaService;
  final AssistantMessageHandler streamHandled;
  final Future<Map<String, dynamic>> Function(
    FunctionCallResponse call,
    List<Map<String, dynamic>> ops,
  )?
  onChecklistToolCall;

  @override
  GemmaInputFieldState createState() => GemmaInputFieldState();
}

class GemmaInputFieldState extends State<GemmaInputField> {
  StreamSubscription<ModelResponse>? _subscription;
  Message _message = Message.text(text: '');
  bool _isGenerating = false;
  bool _updatingChecklist = false;

  @override
  void initState() {
    super.initState();
    unawaited(_processMessages());
  }

  Future<void> _processMessages() async {
    setState(() {
      _isGenerating = true;
      _updatingChecklist =
          widget.gemmaService.usesNativeChecklistTools &&
          widget.onChecklistToolCall != null;
    });
    _subscription = widget.gemmaService
        .processMessageAsync(
          widget.userMessage,
          onChecklistToolCall: widget.onChecklistToolCall,
        )
        .listen(
          (ModelResponse response) {
            if (response is TextResponse) {
              setState(() {
                _updatingChecklist = false;
                _message = Message.text(
                  text: '${_message.text}${response.token}',
                );
              });
            }
          },
          onDone: () async {
            if (mounted) {
              setState(() {
                _isGenerating = false;
                _updatingChecklist = false;
              });
            }
            await widget.streamHandled(_message);
          },
          onError: (Object e, StackTrace st) async {
            if (mounted) {
              setState(() {
                _isGenerating = false;
                _updatingChecklist = false;
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
    // Cancelling the stream reaches the native litertlm cancel, which wedges
    // the conversation; have the service rebuild the session before next turn.
    widget.gemmaService.markGenerationStopped();
    if (mounted) {
      setState(() => _isGenerating = false);
    }
    // Commit whatever was generated so far
    await widget.streamHandled(_message);
  }

  @override
  void dispose() {
    // A generation cut short by teardown (e.g. sending the next message while
    // this one streams) wedges the native session exactly like the stop
    // button — recover on the next turn.
    if (_isGenerating) {
      widget.gemmaService.markGenerationStopped();
    }
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
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_updatingChecklist && _message.text.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'chat_updating_checklist'.tr(),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ChatMessageWidget(message: _message),
            ],
          ),
        ),
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
