import '../models/daily_plan.dart';
import 'api_client.dart';
import 'offline_mutation_queue.dart';

class DailyPlannerService {
  final _api = ApiClient.instance;
  final _offline = OfflineMutationQueue.instance;

  String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DailyPlan> getPlan(DateTime date) async {
    final dateText = _date(date);
    dynamic response;

    try {
      response = await _api.get(
        'daily-planner?date=$dateText',
        cacheable: false,
      );
    } catch (e) {
      if (!ApiClient.isTransientNetworkError(e)) rethrow;
      response = await _api.get(
        'daily-planner?date=$dateText',
        cacheable: true,
      );
    }

    final map = _normalisePlanPayload(response, dateText);
    return DailyPlan.fromJson(await _overlay(map, dateText));
  }

  Map<String, dynamic> _normalisePlanPayload(
    dynamic response,
    String dateText,
  ) {
    dynamic payload = response;

    for (var i = 0; i < 4; i++) {
      if (payload is! Map) break;
      final current = Map<String, dynamic>.from(payload);

      if (current['data'] is Map) {
        payload = current['data'];
        continue;
      }
      if (current['daily_planner'] is Map) {
        payload = current['daily_planner'];
        continue;
      }
      if (current['planner'] is Map) {
        payload = current['planner'];
        continue;
      }
      break;
    }

    if (payload is! Map) {
      return <String, dynamic>{
        'plan': <String, dynamic>{
          'id': 0,
          'plan_date': dateText,
          'title': 'My Daily Plan',
        },
        'items': <Map<String, dynamic>>[],
      };
    }

    final map = Map<String, dynamic>.from(payload);

    dynamic rawItems = map['items'] ??
        map['daily_plan_items'] ??
        map['tasks'] ??
        map['plan_items'];

    if (rawItems == null && map['plan'] is Map) {
      final plan = Map<String, dynamic>.from(map['plan'] as Map);
      rawItems = plan['items'] ??
          plan['daily_plan_items'] ??
          plan['tasks'] ??
          plan['plan_items'];
    }

    final planMap = map['plan'] is Map
        ? Map<String, dynamic>.from(map['plan'] as Map)
        : <String, dynamic>{
            'id': map['id'] ?? 0,
            'plan_date': map['plan_date'] ?? map['date'] ?? dateText,
            'title': map['title'] ?? 'My Daily Plan',
            'notes': map['notes'],
            'achievements': map['achievements'],
            'challenges': map['challenges'],
          };

    planMap['plan_date'] =
        planMap['plan_date'] ?? map['plan_date'] ?? map['date'] ?? dateText;

    return <String, dynamic>{
      ...map,
      'plan': planMap,
      'items': rawItems is List ? rawItems : const <dynamic>[],
    };
  }

  Future<Map<String, dynamic>> _overlay(Map<String, dynamic> raw, String dateText) async {
    final plan = Map<String, dynamic>.from((raw['plan'] as Map?) ?? const {});
    final list = (raw['items'] as List? ?? plan['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final byId = <int, Map<String, dynamic>>{};
    final order = <int>[];
    for (final row in list) {
      final id = (row['id'] as num?)?.toInt();
      if (id != null) { byId[id] = row; order.add(id); }
    }

    final pending = await _offline.forPrefix('daily-planner');
    for (final m in pending) {
      if (m.path == 'daily-planner' && m.method == 'PUT' && m.body['plan_date']?.toString() == dateText) {
        plan.addAll(m.body);
        plan['_offline_pending'] = true;
        continue;
      }
      if (m.path == 'daily-planner/items' && m.method == 'POST' && m.localId != null) {
        if (m.body['plan_date']?.toString() != dateText) continue;
        final row = {...m.body, 'id': m.localId, 'is_completed': false, '_offline_pending': true};
        byId[m.localId!] = row;
        if (!order.contains(m.localId)) order.add(m.localId!);
        continue;
      }
      if (!m.path.startsWith('daily-planner/items/')) continue;
      final id = int.tryParse(m.path.split('/')[2]);
      if (id == null) continue;
      if (m.method == 'DELETE') {
        byId.remove(id); order.remove(id); continue;
      }
      if (m.method == 'PATCH' && m.path.endsWith('/toggle')) {
        final row = byId[id];
        if (row != null) {
          row['is_completed'] = !(row['is_completed'] == true || row['is_completed'] == 1);
          row['_offline_pending'] = true;
        }
        continue;
      }
      if (m.method == 'PUT') {
        final targetDate = m.body['plan_date']?.toString();
        if (targetDate != null && targetDate != dateText) {
          byId.remove(id); order.remove(id); continue;
        }
        final row = byId[id] ?? <String, dynamic>{'id': id};
        row.addAll(m.body);
        row['_offline_pending'] = true;
        byId[id] = row;
        if (!order.contains(id)) order.add(id);
      }
    }

    final items = order.where(byId.containsKey).map((id) => byId[id]!).toList();
    final completed = items.where((e) => e['is_completed'] == true || e['is_completed'] == 1).length;
    return {
      ...raw,
      'plan': {...plan, 'plan_date': plan['plan_date'] ?? dateText},
      'items': items,
      'total': items.length,
      'completed': completed,
      'pending': items.length - completed,
      'timed': items.where((e) => (e['start_time']?.toString().isNotEmpty ?? false)).length,
      'progress': items.isEmpty ? 0 : ((completed / items.length) * 100).round(),
    };
  }

  Future<DailyPlanHistoryPage> getHistory({
    int page = 1,
    String? search,
    String period = 'all',
    DateTime? from,
    DateTime? to,
    int perPage = 10,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'period': period,
      'per_page': '$perPage',
    };

    final q = search?.trim() ?? '';
    if (q.isNotEmpty) params['q'] = q;
    if (from != null) params['from'] = _date(from);
    if (to != null) params['to'] = _date(to);

    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    final response = await _api.get(
      'daily-planner/history?$query',
      cacheable: false,
    );

    dynamic payload = response;

    // Laravel may return the paginator directly:
    // {data:[...], current_page:1, ...}
    // or wrap it:
    // {data:{data:[...], current_page:1, ...}}
    for (var i = 0; i < 3; i++) {
      if (payload is! Map) break;

      final map = Map<String, dynamic>.from(payload);

      if (map['data'] is Map) {
        payload = map['data'];
        continue;
      }

      break;
    }

    if (payload is! Map) {
      return const DailyPlanHistoryPage(
        data: <DailyPlanHistoryItem>[],
        currentPage: 1,
        lastPage: 1,
        total: 0,
      );
    }

    return DailyPlanHistoryPage.fromJson(
      Map<String, dynamic>.from(payload),
    );
  }

  Future<List<DailyPlanHistoryItem>> getHistoryRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final all = <DailyPlanHistoryItem>[];
    var page = 1;
    var lastPage = 1;

    do {
      final result = await getHistory(
        page: page,
        period: 'all',
        from: from,
        to: to,
        perPage: 100,
      );

      all.addAll(result.data);
      lastPage = result.lastPage < 1 ? 1 : result.lastPage;
      page++;
    } while (page <= lastPage && page <= 20);

    final firstDay = DateTime(from.year, from.month, from.day);
    final lastDay = DateTime(to.year, to.month, to.day);

    // Filter client-side too. This protects Mobile if an older API version
    // accepts from/to but does not actually apply those filters.
    return all.where((item) {
      final date = DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
      );
      return !date.isBefore(firstDay) && !date.isAfter(lastDay);
    }).toList();
  }

  Future<DailyPlan> updatePlan(DateTime date, {required String title, String? notes, String? achievements, String? challenges}) async {
    final body = {'plan_date': _date(date), 'title': title, 'notes': notes, 'achievements': achievements, 'challenges': challenges};
    try {
      final response = await _api.put('daily-planner', body);
      return DailyPlan.fromJson((response as Map).cast<String, dynamic>());
    } catch (e) {
      if (!ApiClient.isTransientNetworkError(e)) rethrow;
      await _offline.enqueue(method: 'PUT', path: 'daily-planner', body: body, module: 'Daily Planner', label: 'Update daily plan');
      return DailyPlan.fromJson({'plan': {...body, 'id': 0, '_offline_pending': true}, 'items': const []});
    }
  }

  Future<DailyPlanItem> addItem(DateTime date, {required String title, String? description, String? achievements, String? challenges, required String priority, String? startTime, String? endTime, int? personalGoalId}) async {
    final body = {'plan_date': _date(date), 'title': title, 'description': description, 'achievements': achievements, 'challenges': challenges, 'priority': priority, 'start_time': startTime, 'end_time': endTime, 'personal_goal_id': personalGoalId};
    try {
      final response = await _api.post('daily-planner/items', body);
      return DailyPlanItem.fromJson((response as Map).cast<String, dynamic>());
    } catch (e) {
      if (!ApiClient.isTransientNetworkError(e)) rethrow;
      final localId = _offline.newLocalId();
      await _offline.enqueue(method: 'POST', path: 'daily-planner/items', body: body, module: 'Daily Planner', label: 'Create planner task', localId: localId);
      return DailyPlanItem.fromJson({...body, 'id': localId, 'is_completed': false, '_offline_pending': true});
    }
  }

  Future<DailyPlanItem> updateItem(int id, {required String title, String? description, String? achievements, String? challenges, DateTime? planDate, required String priority, String? startTime, String? endTime, int? personalGoalId, DateTime? baseUpdatedAt}) async {
    final body = {'title': title, 'description': description, 'achievements': achievements, 'challenges': challenges, if (planDate != null) 'plan_date': _date(planDate), 'priority': priority, 'start_time': startTime, 'end_time': endTime, 'personal_goal_id': personalGoalId};
    if (id < 0) {
      await _offline.updateQueuedCreate(id, {...body, if (planDate != null) 'plan_date': _date(planDate)});
      return DailyPlanItem.fromJson({...body, 'id': id, '_offline_pending': true});
    }
    try {
      final response = await _api.put('daily-planner/items/$id', body);
      return DailyPlanItem.fromJson((response as Map).cast<String, dynamic>());
    } catch (e) {
      if (!ApiClient.isTransientNetworkError(e)) rethrow;
      await _offline.enqueue(method: 'PUT', path: 'daily-planner/items/$id', body: body, module: 'Daily Planner', label: 'Update planner task', baseUpdatedAt: baseUpdatedAt?.toUtc().toIso8601String());
      return DailyPlanItem.fromJson({...body, 'id': id, '_offline_pending': true});
    }
  }

  Future<void> toggle(int id, {DateTime? baseUpdatedAt}) async {
    try {
      if (id < 0) throw const _LocalOfflineAction();
      await _api.patch('daily-planner/items/$id/toggle', {});
    } catch (e) {
      if (e is! _LocalOfflineAction && !ApiClient.isTransientNetworkError(e)) rethrow;
      await _offline.enqueue(method: 'PATCH', path: 'daily-planner/items/$id/toggle', body: const {}, module: 'Daily Planner', label: 'Toggle planner task', baseUpdatedAt: baseUpdatedAt?.toUtc().toIso8601String());
    }
  }

  Future<void> delete(int id, {DateTime? baseUpdatedAt}) async {
    if (id < 0) { await _offline.removeLocalCreate(id); return; }
    try {
      await _api.delete('daily-planner/items/$id');
    } catch (e) {
      if (!ApiClient.isTransientNetworkError(e)) rethrow;
      await _offline.enqueue(method: 'DELETE', path: 'daily-planner/items/$id', body: const {}, module: 'Daily Planner', label: 'Delete planner task', baseUpdatedAt: baseUpdatedAt?.toUtc().toIso8601String());
    }
  }

  Future<void> bulkDeleteItems(List<int> ids) => _api.post('daily-planner/items/bulk-delete', {'ids': ids});
}

class _LocalOfflineAction implements Exception { const _LocalOfflineAction(); }
