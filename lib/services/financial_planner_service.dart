import 'api_client.dart';

class FinancialPlannerSnapshot {
  final Map<String, dynamic> profile;
  final Map<String, dynamic> metrics;
  final String startDate;
  final String endDate;
  const FinancialPlannerSnapshot(
      this.profile, this.metrics, this.startDate, this.endDate);
  factory FinancialPlannerSnapshot.fromJson(Map<String, dynamic> json) =>
      FinancialPlannerSnapshot(
        (json['profile'] as Map).cast<String, dynamic>(),
        (json['metrics'] as Map).cast<String, dynamic>(),
        json['start_date'].toString(),
        json['end_date'].toString(),
      );
}

class FinancialPlannerService {
  final _api = ApiClient.instance;
  Future<FinancialPlannerSnapshot> load(
      {String? startDate, String? endDate}) async {
    final q = <String>[];
    if (startDate != null)
      q.add('start_date=${Uri.encodeQueryComponent(startDate)}');
    if (endDate != null) q.add('end_date=${Uri.encodeQueryComponent(endDate)}');
    final response = await _api.get(
        'financial-planner${q.isEmpty ? '' : '?${q.join('&')}'}',
        cacheable: true);
    return FinancialPlannerSnapshot.fromJson(
        (response as Map).cast<String, dynamic>());
  }

  Future<void> update(Map<String, dynamic> data) =>
      _api.put('financial-planner', data);
}
