import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_sync_result.dart';
import 'api_client.dart';

class MeetingCalendarSyncService {
  const MeetingCalendarSyncService();

  static const _kPending = 'meeting_calendar_sync_pending';
  static const _kProvider = 'meeting_calendar_sync_provider';
  static const _kFrom = 'meeting_calendar_sync_from';
  static const _kTo = 'meeting_calendar_sync_to';
  static const _kRecurring = 'meeting_calendar_sync_recurring';

  String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  /// Persists the currently selected sync range so it can be restored the
  /// next time the sheet opens (and offered again if a sync was interrupted).
  Future<void> saveSelection({
    String provider = 'all',
    required DateTime from,
    required DateTime to,
    bool includeRecurring = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvider, provider);
    await prefs.setString(_kFrom, _date(from));
    await prefs.setString(_kTo, _date(to));
    await prefs.setBool(_kRecurring, includeRecurring);
  }

  /// Returns the last persisted selection, or null when none is stored yet.
  Future<Map<String, dynamic>?> lastSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final fromRaw = prefs.getString(_kFrom);
    final toRaw = prefs.getString(_kTo);
    if (fromRaw == null || toRaw == null) return null;

    return {
      'provider': prefs.getString(_kProvider) ?? 'all',
      'from': DateTime.tryParse(fromRaw),
      'to': DateTime.tryParse(toRaw),
      'includeRecurring': prefs.getBool(_kRecurring) ?? true,
    };
  }

  Future<bool> hasPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPending) ?? false;
  }

  Future<void> markPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPending, true);
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPending, false);
  }

  /// Runs the last pending sync (if any) and clears the pending flag on
  /// success. Returns null when there was nothing pending.
  Future<CalendarSyncResult?> resyncPending() async {
    if (!await hasPending()) return null;

    final selection = await lastSelection();
    final from = selection?['from'] as DateTime?;
    final to = selection?['to'] as DateTime?;
    if (from == null || to == null) {
      await clearPending();
      return null;
    }

    final result = await sync(
      provider: selection!['provider'] == 'all'
          ? null
          : selection['provider'] as String?,
      from: from,
      to: to,
      includeRecurring: selection['includeRecurring'] as bool? ?? true,
    );

    await clearPending();
    return result;
  }

  Future<CalendarSyncResult> sync({
    String? provider,
    required DateTime from,
    required DateTime to,
    bool includeRecurring = true,
  }) async {
    if (to.isBefore(from)) {
      throw ApiException(
          422, 'The sync-to date cannot be before the sync-from date.');
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
