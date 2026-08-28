import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../widgets/api_list_screen.dart';

class NotificationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends State<NotificationDetailScreen> {
  late Map<String, dynamic> item;
  bool markingRead = false;

  @override
  void initState() {
    super.initState();
    item = Map<String, dynamic>.from(widget.notification);
  }

  ApiService get api => ApiProvider.read(context);

  Map<String, dynamic> get payload {
    final raw = item['data'];

    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return const <String, dynamic>{};
  }

  String get title {
    final value = item['title'] ?? payload['title'];
    return value?.toString().trim().isNotEmpty == true
        ? value.toString()
        : 'Notification';
  }

  String get message {
    final value = item['message'] ??
        payload['message'] ??
        payload['body'];

    return value?.toString().trim() ?? '';
  }

  String get eventType {
    final value = payload['event'] ??
        payload['type'] ??
        item['type'];

    return value
            ?.toString()
            .replaceAll('_', ' ')
            .trim() ??
        'notification';
  }

  IconData get icon {
    final value = eventType.toLowerCase();

    if (value.contains('departure') ||
        value.contains('check out')) {
      return Icons.logout_rounded;
    }

    if (value.contains('arrival') ||
        value.contains('check in')) {
      return Icons.login_rounded;
    }

    if (value.contains('task')) {
      return Icons.task_alt_rounded;
    }

    if (value.contains('stock') ||
        value.contains('inventory')) {
      return Icons.inventory_2_outlined;
    }

    if (value.contains('payment')) {
      return Icons.payments_outlined;
    }

    return Icons.notifications_none_rounded;
  }

  String formatValue(dynamic value) {
    if (value == null) return '—';

    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    if (value is num) {
      return value.toString();
    }

    if (value is List) {
      if (value.isEmpty) return '—';
      return value.map(formatValue).join(', ');
    }

    if (value is Map) {
      if (value.isEmpty) return '—';

      return value.entries
          .map(
            (entry) =>
                '${labelFor(entry.key.toString())}: '
                '${formatValue(entry.value)}',
          )
          .join('\n');
    }

    final raw = value.toString().trim();

    if (raw.isEmpty) return '—';

    final parsed = DateTime.tryParse(raw);

    if (parsed != null && raw.length >= 10) {
      return DateFormat(
        'dd MMM yyyy, h:mm a',
      ).format(parsed.toLocal());
    }

    return raw;
  }

  String labelFor(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  bool shouldHide(String key) {
    return const {
      'title',
      'message',
      'body',
      'event',
      'url',
      'icon',
    }.contains(key);
  }

  Future<void> markRead() async {
    if (markingRead || item['read_at'] != null) {
      return;
    }

    final id = item['id']?.toString();

    if (id == null || id.isEmpty) {
      return;
    }

    setState(() => markingRead = true);

    try {
      await api.postMap(
        '/notifications/$id/read',
        const {},
      );

      if (!mounted) return;

      setState(() {
        item['read_at'] = DateTime.now().toIso8601String();
        markingRead = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Notification marked as read.'),
          ),
        );
    } catch (error) {
      if (!mounted) return;

      setState(() => markingRead = false);

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
    final detailEntries = payload.entries
        .where(
          (entry) => !shouldHide(entry.key),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification'),
        actions: [
          if (item['read_at'] == null)
            IconButton(
              tooltip: 'Mark as read',
              onPressed: markingRead ? null : markRead,
              icon: const Icon(
                Icons.mark_email_read_outlined,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .10),
                        child: Icon(
                          icon,
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              eventType,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (item['created_at'] != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      formatValue(item['created_at']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (detailEntries.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    ...detailEntries.asMap().entries.map(
                      (indexed) {
                        final index = indexed.key;
                        final entry = indexed.value;

                        return Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 118,
                                    child: Text(
                                      labelFor(entry.key),
                                      style: TextStyle(
                                        color:
                                            Colors.grey.shade700,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SelectableText(
                                      formatValue(entry.value),
                                      style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (index <
                                detailEntries.length - 1)
                              const Divider(height: 1),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
