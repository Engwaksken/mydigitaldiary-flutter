import 'api_client.dart';
import 'daily_planner_service.dart';

class EngagementService {
  const EngagementService();

  Future<Map<String, dynamic>> today() async {
    Map<String, dynamic> engagement = <String, dynamic>{};

    try {
      final response = await ApiClient.instance.get(
        'engagement/today',
        cacheable: false,
      );
      engagement = _unwrap(response);
    } catch (_) {}

    try {
      final now = DateTime.now();
      final plan = await DailyPlannerService().getPlan(
        DateTime(now.year, now.month, now.day),
      );

      final progress = engagement['progress'] is Map
          ? Map<String, dynamic>.from(
              engagement['progress'] as Map,
            )
          : <String, dynamic>{};

      engagement['progress'] = <String, dynamic>{
        ...progress,
        'tasks_total': plan.total,
        'tasks_completed': plan.completed,
        'tasks_pending': plan.pending,
        'completion_percent':
            plan.total == 0 ? 0 : ((plan.completed / plan.total) * 100).round(),
      };

      final start = engagement['start_day'] is Map
          ? Map<String, dynamic>.from(
              engagement['start_day'] as Map,
            )
          : <String, dynamic>{};

      engagement['start_day'] = <String, dynamic>{
        ...start,
        'focus_count': plan.pending,
      };
    } catch (_) {}

    return engagement;
  }

  Future<Map<String, dynamic>> startDay({
    String? reflection,
    int? mood,
  }) async {
    final payload = <String, dynamic>{
      if (reflection != null && reflection.trim().isNotEmpty)
        'reflection': reflection.trim(),
      if (mood != null) 'mood': mood,
    };

    final response = await ApiClient.instance.post(
      'engagement/checkin/start-day',
      payload,
    );

    return _unwrap(response);
  }

  Future<Map<String, dynamic>> closeDay({
    String? reflection,
    String? gratitude,
    String? tomorrowFocus,
    int? mood,
  }) async {
    final payload = <String, dynamic>{
      if (reflection != null && reflection.trim().isNotEmpty)
        'reflection': reflection.trim(),
      if (gratitude != null && gratitude.trim().isNotEmpty)
        'gratitude': gratitude.trim(),
      if (tomorrowFocus != null && tomorrowFocus.trim().isNotEmpty)
        'tomorrow_focus': tomorrowFocus.trim(),
      if (mood != null) 'mood': mood,
    };

    final response = await ApiClient.instance.post(
      'engagement/checkin/close-day',
      payload,
    );

    return _unwrap(response);
  }

  Future<Map<String, dynamic>> review(String period) async {
    Map<String, dynamic> review = <String, dynamic>{};

    // Keep non-task metrics from the Laravel engagement service:
    // streaks, meaningful days, exercise, etc.
    try {
      final response = await ApiClient.instance.get(
        'engagement/review/$period',
        cacheable: false,
      );
      review = _unwrap(response);
    } catch (_) {}

    final range = _range(period);

    // Tasks are sourced from Daily Planner history, not today's plan.
    try {
      final planner = await _plannerReview(
        from: range.$1,
        to: range.$2,
      );

      review = <String, dynamic>{
        ...review,
        'tasks_total': planner.total,
        'tasks_completed': planner.completed,
        'completion_percent': planner.total == 0
            ? 0
            : ((planner.completed / planner.total) * 100).round(),
        'planner_days': planner.days,
        'period_start': _date(range.$1),
        'period_end': _date(range.$2),
      };
    } catch (_) {}

    // Income and expenses are fetched independently for exactly the same
    // week/month. This avoids relying on engagement/review to calculate money.
    try {
      final finance = await _financeReview(
        from: range.$1,
        to: range.$2,
      );

      review = <String, dynamic>{
        ...review,
        'income': finance.income,
        'expenses': finance.expenses,
      };
    } catch (_) {}

    return review;
  }

  (DateTime, DateTime) _range(String period) {
    final now = DateTime.now();

    if (period == 'month') {
      return (
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 0),
      );
    }

    final monday = now.subtract(
      Duration(days: now.weekday - DateTime.monday),
    );

    final start = DateTime(
      monday.year,
      monday.month,
      monday.day,
    );

    return (
      start,
      start.add(const Duration(days: 6)),
    );
  }

  Future<_PlannerReview> _plannerReview({
    required DateTime from,
    required DateTime to,
  }) async {
    final service = DailyPlannerService();

    // Use the history endpoint because /daily-planner?date=... on older
    // deployments can resolve back to today's plan. History is the correct
    // endpoint for week/month summaries.
    final history = await service.getHistoryRange(
      from: from,
      to: to,
    );

    var total = 0;
    var completed = 0;
    var days = 0;

    for (final day in history) {
      total += day.total;
      completed += day.completed;
      if (day.total > 0) days++;
    }

    // History endpoints often exclude the currently-open plan until it has
    // historical activity. Merge today once, but never use today as a
    // substitute for the whole period.
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final withinRange = !today.isBefore(from) && !today.isAfter(to);

    final historyHasToday = history.any(
      (day) =>
          day.date.year == today.year &&
          day.date.month == today.month &&
          day.date.day == today.day,
    );

    if (withinRange && !historyHasToday) {
      try {
        final todayPlan = await service.getPlan(today);
        total += todayPlan.total;
        completed += todayPlan.completed;
        if (todayPlan.total > 0) days++;
      } catch (_) {}
    }

    return _PlannerReview(
      total: total,
      completed: completed,
      days: days,
    );
  }

  Future<_FinanceReview> _financeReview({
    required DateTime from,
    required DateTime to,
  }) async {
    final results = await Future.wait<double>([
      _sumEndpoint(
        endpoint: 'incomes',
        dateFields: const ['received_at', 'date', 'created_at'],
        amountFields: const ['amount', 'total'],
        from: from,
        to: to,
      ),
      _sumEndpoint(
        endpoint: 'expenses',
        dateFields: const ['spent_at', 'date', 'created_at'],
        amountFields: const ['amount', 'total'],
        from: from,
        to: to,
      ),
    ]);

    return _FinanceReview(
      income: results[0],
      expenses: results[1],
    );
  }

  Future<double> _sumEndpoint({
    required String endpoint,
    required List<String> dateFields,
    required List<String> amountFields,
    required DateTime from,
    required DateTime to,
  }) async {
    var page = 1;
    var lastPage = 1;
    var total = 0.0;

    final start = DateTime(
      from.year,
      from.month,
      from.day,
    );

    final end = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
    );

    do {
      final query = [
        'page=$page',
        'per_page=100',
        'period=custom',
        'from=${_date(from)}',
        'to=${_date(to)}',
      ].join('&');

      final response = await ApiClient.instance.get(
        '$endpoint?$query',
        cacheable: false,
      );

      final pageData = _listPage(response);
      lastPage = pageData.lastPage;

      for (final row in pageData.rows) {
        DateTime? rowDate;

        for (final field in dateFields) {
          final raw = row[field];
          if (raw == null) continue;

          rowDate = DateTime.tryParse(
            raw.toString(),
          )?.toLocal();

          if (rowDate != null) break;
        }

        // When the API ignored from/to, filter it here on the phone.
        if (rowDate != null &&
            (rowDate.isBefore(start) || rowDate.isAfter(end))) {
          continue;
        }

        dynamic amount;

        for (final field in amountFields) {
          if (row[field] != null) {
            amount = row[field];
            break;
          }
        }

        total += _number(amount);
      }

      page++;
    } while (page <= lastPage && page <= 100);

    return total;
  }

  _ListPage _listPage(dynamic response) {
    dynamic payload = response;

    // Accept:
    // {data:[...], last_page:...}
    // {data:{data:[...], last_page:...}}
    // [...]
    if (payload is Map && payload['data'] is Map) {
      payload = payload['data'];
    }

    if (payload is List) {
      return _ListPage(
        rows: payload
            .whereType<Map>()
            .map(
              (row) => Map<String, dynamic>.from(row),
            )
            .toList(),
        lastPage: 1,
      );
    }

    if (payload is! Map) {
      return const _ListPage(
        rows: <Map<String, dynamic>>[],
        lastPage: 1,
      );
    }

    final map = Map<String, dynamic>.from(payload);
    final rawRows = map['data'] is List
        ? map['data']
        : (map['items'] is List ? map['items'] : const []);

    dynamic lastPageValue = map['last_page'];
    if (lastPageValue == null && map['meta'] is Map) {
      lastPageValue = (map['meta'] as Map)['last_page'];
    }

    final last = _int(lastPageValue, 1);

    return _ListPage(
      rows: (rawRows as List)
          .whereType<Map>()
          .map(
            (row) => Map<String, dynamic>.from(row),
          )
          .toList(),
      lastPage: last < 1 ? 1 : last,
    );
  }

  int _int(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(
          value?.toString().replaceAll(',', '').replaceAll('UGX', '').trim() ??
              '',
        ) ??
        0;
  }

  Future<Map<String, dynamic>> shareCard(
    String period,
  ) async {
    final response = await ApiClient.instance.get(
      'engagement/share-card/$period',
      cacheable: false,
    );

    return _unwrap(response);
  }

  Future<void> meaningfulAction({
    required String eventType,
    String? sourceType,
    int? sourceId,
    Map<String, dynamic>? meta,
  }) async {
    final payload = <String, dynamic>{
      'event_type': eventType,
      if (sourceType != null && sourceType.trim().isNotEmpty)
        'source_type': sourceType.trim(),
      if (sourceId != null) 'source_id': sourceId,
      if (meta != null && meta.isNotEmpty) 'meta': meta,
    };

    await ApiClient.instance.post(
      'engagement/meaningful-action',
      payload,
    );
  }

  String _date(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _unwrap(dynamic response) {
    if (response is Map && response['data'] is Map) {
      return Map<String, dynamic>.from(
        response['data'] as Map,
      );
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return <String, dynamic>{};
  }
}

class _PlannerReview {
  final int total;
  final int completed;
  final int days;

  const _PlannerReview({
    required this.total,
    required this.completed,
    required this.days,
  });
}

class _FinanceReview {
  final double income;
  final double expenses;

  const _FinanceReview({
    required this.income,
    required this.expenses,
  });
}

class _ListPage {
  final List<Map<String, dynamic>> rows;
  final int lastPage;

  const _ListPage({
    required this.rows,
    required this.lastPage,
  });
}
