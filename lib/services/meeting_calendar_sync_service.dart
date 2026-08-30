import '../models/calendar_sync_result.dart';
import 'api_client.dart';

class MeetingCalendarSyncService {
  const MeetingCalendarSyncService();

  String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  Future<CalendarSyncResult> sync({
    String? provider,
    required DateTime from,
    required DateTime to,
    bool includeRecurring = true,
  }) async {
    if (to.isBefore(from)) {
      throw ApiException(422, 'The sync-to date cannot be before the sync-from date.');
    }

    final response = await ApiClient.instance.post(
      'meetings/sync-calendar',
      <String, dynamic>{
        'provider': provider,
        'sync_from_date': _date(from),
        'sync_to_date': _date(to),
        'include_recurring': includeRecurring,
      },
    );

    dynamic payload = response;
    if (payload is Map && payload['data'] is Map) {
      payload = payload['data'];
    }

    if (payload is! Map) {
      throw ApiException(500, 'Calendar sync returned an invalid response.');
    }

    return CalendarSyncResult.fromJson(
      Map<String, dynamic>.from(payload),
    );
  }
}
