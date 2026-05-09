import 'package:disastron/shared/widgets/genui_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({required this.message, super.key});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    if (message.type == MessageType.systemInfo) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: GenUiCard(
            title: 'Todos',
            subtitle: message.text,
            trailing: Icon(Icons.checklist_rounded, color: cs.primary),
            child: const SizedBox.shrink(),
          ),
        ),
      );
    }

    final bool assistantCopy =
        !message.isUser && message.text.trim().isNotEmpty;
    final bool showAssistantSpinner = !message.isUser &&
        message.text.trim().isEmpty &&
        !message.hasImage;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          if (message.isUser) const SizedBox() else _buildAvatar(),
          const SizedBox(
            width: 10,
          ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (assistantCopy)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Copy',
                        icon: const Icon(Icons.copy, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: message.text),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied')),
                            );
                          }
                        },
                      ),
                    ),
                  if (message.hasImage && message.imageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 200,
                            maxWidth: 280,
                          ),
                          child: Image.memory(
                            message.imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  if (message.text.isNotEmpty)
                    MarkdownBody(data: message.text)
                  else if (showAssistantSpinner)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          if (message.isUser) _buildAvatar() else const SizedBox(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return message.isUser ? const Icon(Icons.person) : _circled('assets/images/icon.png');
  }

  Widget _circled(String image) =>
      CircleAvatar(backgroundColor: Colors.transparent, foregroundImage: AssetImage(image));
}
