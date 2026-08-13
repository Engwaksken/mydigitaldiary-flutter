import '../models/annual_plan.dart';
import 'api_client.dart';

class AnnualPlannerService {
  final _api = ApiClient.instance;

  Future<AnnualPlanSummary> getPlans({required int year, String? search}) async {
    final q = search?.trim() ?? '';
    final response = await _api.get(
      'annual-plans?year=$year${q.isEmpty ? '' : '&q=${Uri.encodeQueryComponent(q)}'}',
      cacheable: true,
    );
    return AnnualPlanSummary.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<AnnualPlan> create({
    required String title,
    required int year,
    String? description,
    DateTime? targetDate,
    required int progressPercent,
  }) async {
    final response = await _api.post('annual-plans', {
      'title': title,
      'plan_year': year,
      'description': description,
      'target_date': targetDate == null ? null : _date(targetDate),
      'progress_percent': progressPercent,
    });
    return AnnualPlan.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<AnnualPlan> update(AnnualPlan plan, {
    required String title,
    required int year,
    String? description,
    DateTime? targetDate,
    required int progressPercent,
  }) async {
    final response = await _api.put('annual-plans/${plan.id}', {
      'title': title,
      'plan_year': year,
      'description': description,
      'target_date': targetDate == null ? null : _date(targetDate),
      'progress_percent': progressPercent,
    });
    return AnnualPlan.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> toggle(AnnualPlan plan, bool completed) async {
    await _api.patch('annual-plans/${plan.id}/toggle', {'completed': completed});
  }

  Future<void> delete(int id) => _api.delete('annual-plans/$id');

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
