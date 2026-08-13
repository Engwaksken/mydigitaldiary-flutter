import '../models/daily_plan.dart';
import 'api_client.dart';

class DailyPlannerService {
  final _api = ApiClient.instance;

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DailyPlan> getPlan(DateTime date) async {
    final response = await _api.get('daily-planner?date=${_date(date)}', cacheable: false);
    return DailyPlan.fromJson((response as Map).cast<String, dynamic>());
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
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final response = await _api.get('daily-planner/history?$query', cacheable: false);
    return DailyPlanHistoryPage.fromJson((response as Map).cast<String, dynamic>());
  }

  Future<DailyPlan> updatePlan(
    DateTime date, {
    required String title,
    String? notes,
  }) async {
    final response = await _api.put('daily-planner', {
      'plan_date': _date(date),
      'title': title,
      'notes': notes,
    });
    return DailyPlan.fromJson((response as Map).cast<String, dynamic>());
  }

  Future<DailyPlanItem> addItem(
    DateTime date, {
    required String title,
    String? description,
    required String priority,
    String? startTime,
    String? endTime,
  }) async {
    final response = await _api.post('daily-planner/items', {
      'plan_date': _date(date),
      'title': title,
      'description': description,
      'priority': priority,
      'start_time': startTime,
      'end_time': endTime,
    });
    return DailyPlanItem.fromJson((response as Map).cast<String, dynamic>());
  }

  Future<DailyPlanItem> updateItem(
    int id, {
    required String title,
    String? description,
    required String priority,
    String? startTime,
    String? endTime,
  }) async {
    final response = await _api.put('daily-planner/items/$id', {
      'title': title,
      'description': description,
      'priority': priority,
      'start_time': startTime,
      'end_time': endTime,
    });
    return DailyPlanItem.fromJson((response as Map).cast<String, dynamic>());
  }

  Future<void> toggle(int id) => _api.patch('daily-planner/items/$id/toggle', {});
  Future<void> delete(int id) => _api.delete('daily-planner/items/$id');
}
