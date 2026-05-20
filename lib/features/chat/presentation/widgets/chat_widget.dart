import 'package:disastron/features/chat/presentation/chat_handlers.dart';
import 'package:disastron/features/chat/presentation/service/gemma_service.dart';
import 'package:disastron/features/chat/presentation/widgets/accident_chips_panel.dart';
import 'package:disastron/features/chat/presentation/widgets/chat_input_field.dart';
import 'package:disastron/features/chat/presentation/widgets/chat_message.dart';
import 'package:disastron/features/chat/presentation/widgets/gemma_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class ChatListWidget extends StatelessWidget {
  const ChatListWidget({
    required this.messages,
    required this.gemmaHandler,
    required this.humanHandler,
    required this.gemmaService,
    required this.showAccidentChips,
    required this.onAccidentChip,
    required this.isImageSupported,
    super.key,
  });

  final List<Message> messages;
  final GemmaLocalService gemmaService;
  final AssistantMessageHandler gemmaHandler;
  final HumanMessageHandler humanHandler;
  final bool showAccidentChips;
  final void Function(AccidentChipOption option) onAccidentChip;
  final bool isImageSupported;

  @override
  Widget build(BuildContext context) {
    final int chipExtra = showAccidentChips && messages.isEmpty ? 1 : 0;
    final int itemCount = messages.length + 2 + chipExtra;

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      reverse: true,
      itemCount: itemCount,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          if (messages.isNotEmpty && messages.last.isUser) {
            return GemmaInputField(
              userMessage: messages.last,
              gemmaService: gemmaService,
              streamHandled: gemmaHandler,
            );
          }
          if (messages.isEmpty || !messages.last.isUser) {
            return ChatInputField(
              isImageSupported: isImageSupported,
              onSubmitted: humanHandler,
            );
          }
        } else if (index == 1) {
          return const Divider(height: 1);
        } else if (chipExtra == 1 && index == 2 && messages.isEmpty) {
          return AccidentChipsPanel(onSelect: onAccidentChip);
        } else {
          final int messageIndex = index - 2 - chipExtra;
          final Message message = messages.reversed.toList()[messageIndex];
          return ChatMessageWidget(
            message: message,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
