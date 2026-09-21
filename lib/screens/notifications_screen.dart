import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification.dart';
import '../services/notification_list_service.dart';
import '../services/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationListService();
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.list();
      setState(() {
        _notifications = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _tapNotification(AppNotification notification) async {
    if (!notification.read) {
      try {
        await _service.markRead(notification.id);
        setState(() {
          _notifications = _notifications.map((n) {
            return n.id == notification.id
                ? AppNotification(
                    id: n.id,
                    type: n.type,
                    data: n.data,
                    read: true,
                    createdAt: n.createdAt)
                : n;
          }).toList();
        });
      } on ApiException catch (_) {
        // Non-critical — a failed "mark as read" shouldn't block viewing
        // the notification's content, so this is intentionally silent.
      }
    }

    // The list only shows the title (displayMessage()) — an
    // announcement's whole point is the message body, so it's worth
    // a full-text dialog rather than leaving it permanently truncated.
    if (notification.type == 'AnnouncementNotification' && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(notification.data['title'] ?? 'Announcement'),
          content: Text(notification.data['body'] ?? ''),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.read);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No notifications yet.',
                              textAlign: TextAlign.center),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          elevation: notification.read ? 0 : 1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          color: notification.read
                              ? null
                              : const Color(0xFFF1F5F9),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: notification.read
                                  ? Colors.grey.withValues(alpha: 0.15)
                                  : const Color(0x1A00897B),
                              child: Icon(
                                notification.read
                                    ? Icons.notifications_none
                                    : Icons.notifications_active,
                                color: notification.read
                                    ? Colors.grey
                                    : const Color(0xFF00897B),
                              ),
                            ),
                            title: Text(
                              notification.displayMessage(),
                              style: TextStyle(
                                  fontWeight: notification.read
                                      ? FontWeight.normal
                                      : FontWeight.w600),
                            ),
                            subtitle: Text(DateFormat('yMMMd, h:mm a')
                                .format(notification.createdAt)),
                            onTap: () => _tapNotification(notification),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
