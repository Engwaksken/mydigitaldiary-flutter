import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/team_chat_models.dart';
import '../services/team_chat_service.dart';

class TeamChatScreen extends StatefulWidget {
  final int conversationId;

  const TeamChatScreen({
    required this.conversationId,
    super.key,
  });

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final TeamChatService _service = TeamChatService();
  final TextEditingController _messageController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();

  TeamChatThread? _thread;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  TeamChatMessage? _replyingTo;
  List<PlatformFile> _attachments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final thread = await _service.thread(widget.conversationId);

      if (!mounted) return;

      setState(() {
        _thread = thread;
        _loading = false;
        _error = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result == null || !mounted) return;

    setState(() {
      _attachments = result.files.take(8).toList(growable: false);
    });
  }

  Future<void> _send() async {
    final body = _messageController.text.trim();

    if (body.isEmpty && _attachments.isEmpty) return;

    setState(() => _sending = true);

    try {
      await _service.send(
        conversationId: widget.conversationId,
        body: body,
        replyToId: _replyingTo?.id,
        attachments: _attachments,
      );

      _messageController.clear();

      if (mounted) {
        setState(() {
          _replyingTo = null;
          _attachments = const [];
        });
      }

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = _thread;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          thread?.conversation.name ?? 'Team Chat',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: thread!.messages.length,
                          itemBuilder: (context, index) {
                            final message = thread.messages[index];

                            return _MessageCard(
                              message: message,
                              onReply: () {
                                setState(() => _replyingTo = message);
                              },
                              onReact: (reaction) async {
                                await _service.react(
                                  message.id,
                                  reaction,
                                );
                                _load();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    if (_replyingTo != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        color: Colors.grey.shade100,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to ${_replyingTo!.senderName}: '
                                '${_replyingTo!.body}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() => _replyingTo = null);
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    if (_attachments.isNotEmpty)
                      SizedBox(
                        height: 46,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          children: _attachments
                              .map(
                                (file) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: Text(
                                      file.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: _sending ? null : _pickFiles,
                              icon: const Icon(Icons.attach_file),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  hintText: 'Message the team…',
                                ),
                              ),
                            ),
                            IconButton.filled(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final TeamChatMessage message;
  final VoidCallback onReply;
  final ValueChanged<String> onReact;

  const _MessageCard({
    required this.message,
    required this.onReply,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: message.isAnnouncement
          ? const Color(0xFFFFFBEB)
          : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message.senderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (message.isAnnouncement)
                  const Chip(
                    label: Text('Announcement'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (message.replyTo != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${message.replyTo!['sender_name'] ?? 'Member'}: '
                  '${message.replyTo!['body'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (message.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message.body),
            ],
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...message.attachments.map(
                (file) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: Text(file.name),
                  subtitle: Text(
                    '${(file.sizeBytes / 1024).toStringAsFixed(1)} KB',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: onReply,
                  child: const Text('Reply'),
                ),
                for (final item in const {
                  'like': '👍',
                  'love': '❤️',
                  'celebrate': '🎉',
                  'support': '🙌',
                }.entries)
                  TextButton(
                    onPressed: () => onReact(item.key),
                    child: Text(item.value),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
