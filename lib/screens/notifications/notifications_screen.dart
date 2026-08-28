import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../widgets/api_list_screen.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;
  bool started = false;
  bool markingAll = false;
  String? error;

  ApiService get api => ApiProvider.read(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!started) {
      started = true;
      loadNotifications();
    }
  }

  Future<void> loadNotifications() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final rows = await api.getList('/notifications');

      if (!mounted) return;

      setState(() {
        notifications = rows.map((row) {
          if (row is Map<String, dynamic>) {
            return row;
          }

          if (row is Map) {
            return Map<String, dynamic>.from(row);
          }

          return <String, dynamic>{
            'title': 'Notification',
            'message': row.toString(),
          };
        }).toList();

        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;

      setState(() {
        error = api.readableError(exception);
        loading = false;
      });
    }
  }

  Map<String, dynamic> payloadOf(
    Map<String, dynamic> item,
  ) {
    final raw = item['data'];

    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return const {};
  }

  String titleOf(Map<String, dynamic> item) {
    final payload = payloadOf(item);

    final value = item['title'] ??
        payload['title'] ??
        payload['subject'];

    return value?.toString().trim().isNotEmpty == true
        ? value.toString()
        : 'Notification';
  }

  String messageOf(Map<String, dynamic> item) {
    final payload = payloadOf(item);

    final value = item['message'] ??
        payload['message'] ??
        payload['body'];

    return value?.toString().trim() ?? '';
  }

  String eventOf(Map<String, dynamic> item) {
    final payload = payloadOf(item);

    final value = payload['event'] ??
        payload['type'] ??
        item['type'];

    return value
            ?.toString()
            .replaceAll('_', ' ')
            .trim() ??
        'notification';
  }

  IconData iconFor(Map<String, dynamic> item) {
    final event = eventOf(item).toLowerCase();

    if (event.contains('departure') ||
        event.contains('check out')) {
      return Icons.logout_rounded;
    }

    if (event.contains('arrival') ||
        event.contains('check in')) {
      return Icons.login_rounded;
    }

    if (event.contains('task')) {
      return Icons.task_alt_rounded;
    }

    if (event.contains('stock') ||
        event.contains('inventory')) {
      return Icons.inventory_2_outlined;
    }

    if (event.contains('payment')) {
      return Icons.payments_outlined;
    }

    return Icons.notifications_none_rounded;
  }

  String dateOf(Map<String, dynamic> item) {
    final raw = item['created_at']?.toString();

    if (raw == null || raw.isEmpty) {
      return '';
    }

    final date = DateTime.tryParse(raw);

    if (date == null) return raw;

    return DateFormat(
      'dd MMM, h:mm a',
    ).format(date.toLocal());
  }

  Future<void> openNotification(
    Map<String, dynamic> item,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(
          notification: item,
        ),
      ),
    );

    if (mounted) {
      await loadNotifications();
    }
  }

  Future<void> markAllRead() async {
    if (markingAll) return;

    setState(() => markingAll = true);

    try {
      await api.postMap(
        '/notifications/read-all',
        const {},
      );

      if (!mounted) return;

      setState(() => markingAll = false);

      await loadNotifications();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'All notifications marked as read.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;

      setState(() => markingAll = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(api.readableError(error)),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = notifications
        .where((item) => item['read_at'] == null)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            IconButton(
              tooltip: 'Mark all as read',
              onPressed:
                  markingAll ? null : markAllRead,
              icon: const Icon(
                Icons.mark_email_read_outlined,
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                loading ? null : loadNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadNotifications,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (!loading && error == null)
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Text(
                      unread == 0
                          ? 'You are all caught up'
                          : '$unread unread notification${unread == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 42,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: loadNotifications,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (notifications.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 42,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No notifications yet.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...notifications.map((item) {
                final unreadItem =
                    item['read_at'] == null;
                final message = messageOf(item);

                return Container(
                  margin:
                      const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: unreadItem
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: .25)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(16),
                    onTap: () =>
                        openNotification(item),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(
                                          alpha: .10,
                                        ),
                                child: Icon(
                                  iconFor(item),
                                  color:
                                      Theme.of(context)
                                          .colorScheme
                                          .primary,
                                ),
                              ),
                              if (unreadItem)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Theme.of(context)
                                              .colorScheme
                                              .primary,
                                      shape:
                                          BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  titleOf(item),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        unreadItem
                                            ? FontWeight
                                                .w800
                                            : FontWeight
                                                .w700,
                                  ),
                                ),
                                if (message.isNotEmpty) ...[
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Text(
                                    message,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.grey
                                              .shade700,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                if (dateOf(item)
                                    .isNotEmpty) ...[
                                  const SizedBox(
                                    height: 7,
                                  ),
                                  Text(
                                    dateOf(item),
                                    style: TextStyle(
                                      color:
                                          Colors.grey
                                              .shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
