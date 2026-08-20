import 'api_client.dart';

class DueReminder {
  final int id;
  final String title;
  final String? message;
  final DateTime? nextRunAt;

  DueReminder({required this.id, required this.title, this.message, this.nextRunAt});

  factory DueReminder.fromJson(Map<String, dynamic> json) => DueReminder(
        id: json['id'],
        title: json['title'] ?? '',
        message: json['message'],
        nextRunAt: json['next_run_at'] != null ? DateTime.tryParse(json['next_run_at'].toString())?.toLocal() : null,
      );

  String get occurrenceKey {
    final stamp = nextRunAt?.toIso8601String() ?? 'unknown';
    return '$id:$stamp';
  }
}

/// Mobile equivalent of the web dashboard's alarm-popup polling —
/// same due-now endpoint, same one-click global mute. The web app
/// polls from a page that's always loaded in a browser tab; on mobile
/// this only makes sense to run while the app is actually open and in
/// the foreground, which is what MainNavigationScreen's Timer does
/// with this service.
class ReminderAlarmService {
  final _api = ApiClient.instance;

  Future<List<DueReminder>> dueNow() async {
    final response = await _api.get('reminders/due-now');
    final rows = (response as List).cast<Map<String, dynamic>>();
    return rows.map(DueReminder.fromJson).toList();
  }

  Future<bool> toggleMute() async {
    final response = await _api.post('reminders/toggle-mute', {});
    return response['alarms_muted'] as bool;
  }
}
