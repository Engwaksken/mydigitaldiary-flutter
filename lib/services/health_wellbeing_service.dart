import 'api_client.dart';

class HealthWellbeingService {
  const HealthWellbeingService();

  Future<Map<String, dynamic>> summary({
    int days = 7,
    DateTime? date,
  }) async {
    final params = <String>['days=$days'];
    if (date != null) {
      final iso = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      params.add('date=$iso');
    }

    dynamic response = await ApiClient.instance.get(
      'health-wellbeing/summary?${params.join('&')}',
      cacheable: false,
    );

    if (response is Map && response['data'] is Map) {
      response = response['data'];
    }

    return response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{};
  }
}
