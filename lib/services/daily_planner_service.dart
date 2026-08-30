import '../models/daily_planner.dart';
import 'api_client.dart';

class DailyPlannerService {
  final ApiClient _api;

  DailyPlannerService({
    ApiClient? api,
  }) : _api = api ?? ApiClient.instance;

  /// Canonical recurrence-aware loader used by the new Daily Planner screen.
  Future<DailyPlannerSnapshot> day(
    String date, {
    bool cacheable = false,
  }) async {
    final response = await _api.get(
      'daily-planner?date=$date',
      cacheable: cacheable,
    );

    if (response is! Map) {
      throw ApiException(
        500,
        'The Daily Planner returned an invalid response.',
      );
    }

    return DailyPlannerSnapshot.fromJson(
      Map<String, dynamic>.from(response),
    );
  }


  /// Backward-compatible API used by the existing dashboard and
  /// engagement services. The recurrence update must not force those
  /// callers to be rewritten.
  Future<DailyPlannerSnapshot> getPlan(
    DateTime date, {
    bool cacheable = false,
  }) {
    return day(
      _dateOnly(date),
      cacheable: cacheable,
    );
  }

  /// Backward-compatible history helper used by EngagementService.
  ///
  /// Laravel's recurrence-aware endpoint resolves the actual tasks due on
  /// each date, so history must also be loaded date-by-date instead of
  /// reading duplicated task rows.
  Future<List<DailyPlannerSnapshot>> getHistoryRange({
    required DateTime from,
    required DateTime to,
    bool cacheable = true,
  }) async {
    var start = DateTime(
      from.year,
      from.month,
      from.day,
    );

    var end = DateTime(
      to.year,
      to.month,
      to.day,
    );

    if (end.isBefore(start)) {
      final swap = start;
      start = end;
      end = swap;
    }

    // Protect the mobile app from accidentally issuing an unbounded number
    // of requests. Engagement currently uses short insight/report windows.
    final totalDays = end.difference(start).inDays + 1;
    final boundedDays = totalDays.clamp(1, 120);

    final result = <DailyPlannerSnapshot>[];

    for (var offset = 0; offset < boundedDays; offset++) {
      final date = start.add(
        Duration(days: offset),
      );

      try {
        result.add(
          await day(
            _dateOnly(date),
            cacheable: cacheable,
          ),
        );
      } on ApiException catch (e) {
        // A 404/empty historical day should not make engagement insights
        // unusable. Authentication/server errors still propagate.
        if (e.statusCode == 404) {
          continue;
        }
        rethrow;
      }
    }

    return result;
  }

  Future<List<PersonalGoalOption>> goals() async {
    final response = await _api.get(
      'personal-goals?per_page=100',
      cacheable: true,
    );

    dynamic raw = response;

    if (raw is Map && raw['data'] is List) {
      raw = raw['data'];
    }

    if (raw is Map && raw['goals'] is List) {
      raw = raw['goals'];
    }

    if (raw is! List) {
      return const <PersonalGoalOption>[];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => PersonalGoalOption.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> createTask(
    DailyPlannerTaskDraft draft,
  ) async {
    await _api.post(
      'daily-planner/items',
      draft.toJson(creating: true),
    );
  }

  Future<void> updateTask(
    int itemId,
    DailyPlannerTaskDraft draft,
  ) async {
    await _api.put(
      'daily-planner/items/$itemId',
      draft.toJson(creating: false),
    );
  }

  Future<void> toggleTask(
    DailyPlannerItem item,
  ) async {
    await _api.patch(
      'daily-planner/items/${item.id}/toggle',
      <String, dynamic>{
        'occurrence_date': item.occurrenceDate,
      },
    );
  }

  Future<void> deleteTask(
    DailyPlannerItem item, {
    required String scope,
  }) async {
    await _api.deleteWithBody(
      'daily-planner/items/${item.id}',
      <String, dynamic>{
        'occurrence_date': item.occurrenceDate,
        'delete_scope': scope,
      },
    );
  }

  Future<void> moveTask(
    DailyPlannerItem item,
    String targetDate,
  ) async {
    if (item.isRecurring) {
      throw ApiException(
        422,
        'Recurring tasks follow their repeat schedule. Edit the series instead.',
      );
    }

    await _api.patch(
      'daily-planner/items/${item.id}/move',
      <String, dynamic>{
        'target_date': targetDate,
      },
    );
  }
}


String _dateOnly(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
