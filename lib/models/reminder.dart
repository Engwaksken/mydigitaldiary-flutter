/// Matches the `reminders` table / Api\ReminderController's JSON shape.
/// This is the pattern to copy for every other module (Meeting, Expense,
/// Income, Plan, etc.) — one Dart class per Eloquent model, fromJson +
/// toJson, nothing fancier needed for a CRUD-shaped module.
class Reminder {
  final int id;
  final String title;
  final String? module;
  final String? message;
  final String frequency;
  final int? intervalMinutes;
  final DateTime nextRunAt;
  final String channel;
  final bool isActive;
  final bool alarmEnabled;

  Reminder({
    required this.id,
    required this.title,
    required this.module,
    required this.message,
    required this.frequency,
    required this.intervalMinutes,
    required this.nextRunAt,
    required this.channel,
    required this.isActive,
    required this.alarmEnabled,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as int,
      title: json['title'] as String,
      module: json['module'] as String?,
      message: json['message'] as String?,
      frequency: json['frequency'] as String,
      intervalMinutes: json['interval_minutes'] as int?,
      nextRunAt: DateTime.parse(json['next_run_at'] as String).toLocal(),
      channel: json['channel'] as String,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      alarmEnabled: json['alarm_enabled'] == true || json['alarm_enabled'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'module': module,
      'message': message,
      'frequency': frequency,
      'interval_minutes': intervalMinutes,
      'next_run_at': nextRunAt.toIso8601String(),
      'channel': channel,
      'alarm_enabled': alarmEnabled,
    };
  }
}
