class AppNotification {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'],
        type: json['type'] ?? '',
        data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : {},
        read: json['read'] ?? false,
        createdAt: DateTime.tryParse(json['created_at'] ?? '')?.toLocal() ?? DateTime.now(),
      );

  /// Laravel notification "data" payloads vary by notification class —
  /// each one's toArray() has a genuinely different shape, so this
  /// builds a sensible line for each KNOWN type specifically, falling
  /// back to a generic message/line/body field (or the type name
  /// itself) for anything unfamiliar rather than showing nothing.
  String displayMessage() {
    switch (type) {
      case 'ReminderNotification':
        return data['title'] ?? data['message'] ?? 'Reminder';
      case 'SubscriptionExpiryReminderNotification':
        final days = data['days_remaining'];
        return days != null ? 'Your subscription expires in $days day(s)' : 'Subscription expiring soon';
      case 'DailyTopTasksNotification':
        final taskCount = (data['tasks'] as List?)?.length ?? 0;
        return 'Today\'s top $taskCount task(s)';
      case 'PaymentSuccessfulNotification':
        final planName = data['plan_name'];
        return planName != null ? 'Payment received — $planName is now active.' : 'Payment received.';
      case 'PaymentFailedNotification':
        final reason = data['reason'];
        return reason != null ? 'Payment failed: $reason' : 'A payment could not be processed.';
      case 'AnnouncementNotification':
        return data['title'] ?? 'App announcement';
      default:
        return data['message'] ?? data['line'] ?? data['body'] ?? type;
    }
  }
}
