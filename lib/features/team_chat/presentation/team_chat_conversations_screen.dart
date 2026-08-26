import 'package:flutter/material.dart';

import '../models/team_chat_models.dart';
import '../services/team_chat_service.dart';
import 'team_chat_screen.dart';

class TeamChatConversationsScreen extends StatefulWidget {
  const TeamChatConversationsScreen({super.key});

  @override
  State<TeamChatConversationsScreen> createState() =>
      _TeamChatConversationsScreenState();
}

class _TeamChatConversationsScreenState
    extends State<TeamChatConversationsScreen> {
  final TeamChatService _service = TeamChatService();

  bool _loading = true;
  String? _error;
  List<TeamConversation> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.conversations();

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Team Chat',
          style: TextStyle(fontWeight: FontWeight.w800),
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _items[index];

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: item.unreadCount > 0
                            ? Colors.teal.withValues(alpha: .06)
                            : null,
                        leading: CircleAvatar(
                          child: Icon(
                            item.type == 'channel'
                                ? Icons.tag
                                : Icons.forum_outlined,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: item.unreadCount > 0
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          item.lastMessage?.body.isNotEmpty == true
                              ? item.lastMessage!.body
                              : item.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: item.unreadCount > 0
                            ? Badge(
                                label: Text(
                                  '${item.unreadCount}',
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TeamChatScreen(
                                conversationId: item.id,
                              ),
                            ),
                          );

                          _load();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
