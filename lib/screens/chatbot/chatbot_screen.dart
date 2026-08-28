import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/api_list_screen.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final List<_ChatMessage> messages = [
    const _ChatMessage(
      text: 'Hello! How can I help you with the hotel today?',
      fromUser: false,
    ),
  ];

  bool sending = false;

  ApiService get api => ApiProvider.read(context);

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending) return;

    setState(() {
      messages.add(_ChatMessage(text: text, fromUser: true));
      messageController.clear();
      sending = true;
    });
    _scrollToBottom();

    try {
      final response = await api.postMap(
        '/hotel-chatbot/message',
        {'message': text},
      );

      final reply = _extractReply(response);
      if (!mounted) return;

      setState(() {
        messages.add(_ChatMessage(text: reply, fromUser: false));
        sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        messages.add(
          _ChatMessage(
            text: api.readableError(error),
            fromUser: false,
            isError: true,
          ),
        );
        sending = false;
      });
    }

    _scrollToBottom();
  }

  String _extractReply(Map<String, dynamic> response) {
    final candidates = <dynamic>[
      response['reply'],
      response['message'],
      response['answer'],
      response['response'],
    ];

    final data = response['data'];
    if (data is Map) {
      candidates.addAll([
        data['reply'],
        data['message'],
        data['answer'],
        data['response'],
      ]);
    }

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return 'I could not find a response for that question.';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Hotel Chatbot')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                itemCount: messages.length + (sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (sending && index == messages.length) {
                    return const _TypingBubble();
                  }
                  return _MessageBubble(message: messages[index]);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Ask about rooms, services or bookings...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : sendMessage,
                    tooltip: 'Send',
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = message.isError
        ? scheme.errorContainer
        : message.fromUser
            ? scheme.primary
            : scheme.surfaceContainerHighest;
    final foreground = message.isError
        ? scheme.onErrorContainer
        : message.fromUser
            ? scheme.onPrimary
            : scheme.onSurfaceVariant;

    return Align(
      alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.fromUser ? 16 : 4),
            bottomRight: Radius.circular(message.fromUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: foreground, height: 1.35),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 12, bottom: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromUser,
    this.isError = false,
  });

  final String text;
  final bool fromUser;
  final bool isError;
}
