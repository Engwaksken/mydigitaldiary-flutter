import '../models/annual_plan.dart';
import 'api_client.dart';

class AnnualPlannerService {
  final _api = ApiClient.instance;

  Future<AnnualPlanSummary> getPlans({
    required int year,
    String? search,
    String? status,
    String? period,
    int? month,
    int page = 1,
    int perPage = 10,
  }) async {
    final params = <String, String>{
      'year': '$year',
      'page': '$page',
      'per_page': '$perPage',
    };
    if ((search ?? '').trim().isNotEmpty) params['q'] = search!.trim();
    if ((status ?? '').isNotEmpty) params['status'] = status!;
    if ((period ?? '').isNotEmpty) params['period'] = period!;
    if ((month ?? 0) > 0) params['month'] = '$month';
    final query = params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final response = await _api.get('annual-plans?$query', cacheable: false);
    dynamic payload = response;
    if (payload is Map && payload['data'] is Map) payload = payload['data'];
    return AnnualPlanSummary.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  Future<AnnualPlan> create({
    required String title,
    required int year,
    required String period,
    int? month,
    String? description,
    DateTime? targetDate,
    DateTime? reminderAt,
    required int progressPercent,
    int? personalGoalId,
  }) async {
    final response = await _api.post('annual-plans', _payload(
      title: title, year: year, period: period, month: month, description: description,
      targetDate: targetDate, reminderAt: reminderAt, progressPercent: progressPercent, personalGoalId: personalGoalId,
    ));
    return AnnualPlan.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<AnnualPlan> update(AnnualPlan plan, {
    required String title,
    required int year,
    required String period,
    int? month,
    String? description,
    DateTime? targetDate,
    DateTime? reminderAt,
    required int progressPercent,
    int? personalGoalId,
  }) async {
    final response = await _api.put('annual-plans/${plan.id}', _payload(
      title: title, year: year, period: period, month: month, description: description,
      targetDate: targetDate, reminderAt: reminderAt, progressPercent: progressPercent, personalGoalId: personalGoalId,
    ));
    return AnnualPlan.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Map<String, dynamic> _payload({
    required String title,
    required int year,
    required String period,
    int? month,
    String? description,
    DateTime? targetDate,
    DateTime? reminderAt,
    required int progressPercent,
    int? personalGoalId,
  }) => {
    'personal_goal_id': personalGoalId,
    'title': title,
    'plan_year': year,
    'period': period,
    'plan_month': period == 'monthly' ? month : null,
    'description': description,
    'target_date': targetDate == null ? null : _date(targetDate),
    'reminder_at': reminderAt?.toIso8601String(),
    'progress_percent': progressPercent,
  };

  Future<void> toggle(AnnualPlan plan, bool completed) async => _api.patch('annual-plans/${plan.id}/toggle', {'completed': completed});
  Future<void> delete(int id) => _api.delete('annual-plans/$id');
  Future<void> bulkDelete(List<int> ids) => _api.post('annual-plans/bulk-delete', {'ids': ids});

  String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
