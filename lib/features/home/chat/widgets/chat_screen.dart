import 'dart:async';

import 'package:disastron/features/home/chat/service/gemma_service.dart';
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryFixedDim,
        title: const Text('Messages'),
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
              gemmaHandler: (Message message) {
                setState(() {
                  _messages.add(message);
                });
              },
              humanHandler: (String text) {
                setState(() {
                  _messages.add(Message.text(text: text, isUser: true));
                });
              },
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
