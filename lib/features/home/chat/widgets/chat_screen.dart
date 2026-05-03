import 'dart:async';

import 'package:disastron/features/home/chat/first_chat_accident_provider.dart';
import 'package:disastron/features/home/chat/service/gemma_service.dart';
import 'package:disastron/features/home/chat/service/todo_action_parser.dart';
import 'package:disastron/features/home/chat/widgets/accident_chips_panel.dart';
import 'package:disastron/features/home/chat/widgets/chat_widget.dart';
import 'package:disastron/features/home/chat/widgets/loading_widget.dart';
import 'package:disastron/features/home/model/local_gemma_model_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final GemmaLocalService _gemma = GemmaLocalService();
  final List<Message> _messages = <Message>[];
  bool _chatReady = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
      unawaited(_ensureChatReady());
    });
  }

  @override
  void dispose() {
    unawaited(_gemma.close());
    super.dispose();
  }

  Future<void> _ensureChatReady() async {
    if (!FlutterGemma.hasActiveModel()) {
      return;
    }
    try {
      await _gemma.init();
      if (mounted) {
        setState(() {
          _chatReady = true;
          _initError = null;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _chatReady = false;
          _initError = e.toString();
        });
      }
    }
  }

  Future<void> _onAssistantMessage(Message message) async {
    final TodoApplyResult result = await stripTodosAndApply(ref, message.text);
    if (!mounted) {
      return;
    }
    final String trimmedDisplay = result.displayText.trim();
    final String assistantBody =
        trimmedDisplay.isEmpty ? '(Checklist updated.)' : trimmedDisplay;
    setState(() {
      _messages.add(Message.text(text: assistantBody));
      if (result.appliedCount > 0) {
        _messages.add(
          Message(
            text:
                'Checklist updated (${result.appliedCount} action(s)). Open the Todos tab to review.',
            type: MessageType.systemInfo,
          ),
        );
      }
    });
  }

  void _onHumanMessage(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    unawaited(ref.read(firstChatAccidentPromptProvider.notifier).markDone());
    setState(() {
      _messages.add(Message.text(text: trimmed, isUser: true));
    });
  }

  void _onAccidentChip(AccidentChipOption option) {
    unawaited(ref.read(firstChatAccidentPromptProvider.notifier).markDone());
    setState(() {
      _messages.add(Message.text(text: option.prompt, isUser: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocalGemmaModelUi>(localGemmaModelProvider, (LocalGemmaModelUi? previous, LocalGemmaModelUi next) {
      if (next.isReady && !_chatReady) {
        unawaited(_ensureChatReady());
      }
      if (!next.isReady && _chatReady) {
        unawaited(_gemma.close());
        if (mounted) {
          setState(() {
            _chatReady = false;
            _messages.clear();
            _initError = null;
          });
        }
      }
    });

    final LocalGemmaModelUi modelUi = ref.watch(localGemmaModelProvider);
    final AsyncValue<bool> accidentDone = ref.watch(firstChatAccidentPromptProvider);
    final bool showAccidentChips = modelUi.isReady &&
        _chatReady &&
        accidentDone.hasValue &&
        accidentDone.requireValue == false &&
        _messages.isEmpty;

    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerHigh,
        title: const Text('Chat'),
      ),
      body: Stack(
        children: <Widget>[
          if (!modelUi.isReady)
            _NoModelBody(
              onRefresh: () {
                ref.read(localGemmaModelProvider.notifier).refreshFromEngine();
                unawaited(_ensureChatReady());
              },
            )
          else if (_initError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText('Chat init failed: $_initError'),
              ),
            )
          else if (!_chatReady)
            const LoadingWidget(
              message: 'Starting offline assistant…',
            )
          else
            ChatListWidget(
              gemmaService: _gemma,
              showAccidentChips: showAccidentChips,
              onAccidentChip: _onAccidentChip,
              gemmaHandler: _onAssistantMessage,
              humanHandler: _onHumanMessage,
              messages: _messages,
            ),
        ],
      ),
    );
  }
}

class _NoModelBody extends StatelessWidget {
  const _NoModelBody({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'No on-device model yet. Open the Dashboard tab, then import a model file '
              'or download one when you have a network connection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRefresh,
              child: const Text('Check again'),
            ),
          ],
        ),
      ),
    );
  }
}
