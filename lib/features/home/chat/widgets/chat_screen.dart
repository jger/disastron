import 'package:disastron/features/home/chat/widgets/chat_widget.dart';
import 'package:disastron/features/home/chat/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = <Message>[];
  bool _isModelInitialized = false;
  int? _loadingProgress;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    final bool isLoaded = await FlutterGemmaPlugin.instance.isLoaded;
    if (!isLoaded) {
      await for (final int progress in FlutterGemmaPlugin.instance.loadAssetModelWithProgress(fullPath: 'model.bin')) {
        setState(() {
          _loadingProgress = progress;
        });
      }
    }
    await FlutterGemmaPlugin.instance.init(maxTokens: 512);
    setState(() {
      _isModelInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b2351),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b2351),
        title: const Text(
          'Flutter Gemma Example',
          style: TextStyle(fontSize: 20),
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
      body: Stack(
        children: [
          // Center(
          //   child: Image.asset(
          //     'assets/images/background.png',
          //     width: 200,
          //     height: 200,
          //   ),
          // ),
          if (_isModelInitialized)
            ChatListWidget(
              gemmaHandler: (message) {
                setState(() {
                  _messages.add(message);
                });
              },
              humanHandler: (text) {
                setState(() {
                  _messages.add(Message(text: text, isUser: true));
                });
              },
              messages: _messages,
            )
          else
            LoadingWidget(
              message: _loadingProgress == null ? 'Model is checking' : 'Model loading progress:',
              progress: _loadingProgress,
            ),
        ],
      ),
    );
  }
}
