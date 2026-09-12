import 'api_client.dart';

class PersonalManagementService {
  const PersonalManagementService();

  Future<List<Map<String, dynamic>>> list(String endpoint) async {
    dynamic response = await ApiClient.instance.get(endpoint, cacheable: false);
    if (response is Map && response['data'] is List) response = response['data'];
    if (response is Map && response['data'] is Map && response['data']['data'] is List) {
      response = response['data']['data'];
    }
    if (response is Map && response['data'] is List) response = response['data'];
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> savings() async {
    dynamic response = await ApiClient.instance.get('savings', cacheable: false);
    if (response is Map && response['data'] != null) response = response['data'];
    if (response is List) return {'goals': response};
    return response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> routine(String type) async {
    dynamic response = await ApiClient.instance.get('daily-routine/$type', cacheable: false);
    if (response is Map && response['data'] is Map) response = response['data'];
    return response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
  }

  Future<dynamic> create(String endpoint, Map<String, dynamic> body) =>
      ApiClient.instance.post(endpoint, body);

  Future<dynamic> update(String endpoint, int id, Map<String, dynamic> body) =>
      ApiClient.instance.put('$endpoint/$id', body);

  Future<dynamic> remove(String endpoint, int id) =>
      ApiClient.instance.delete('$endpoint/$id');

  Future<dynamic> sendDebtReminder(
    int debtId, {
    required String channel,
    required String recipientScope,
    String? message,
  }) =>
      ApiClient.instance.post(
        'debts/$debtId/reminders/send',
        <String, dynamic>{
          'channel': channel,
          'recipient_scope': recipientScope,
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        },
      );

  Future<dynamic> saveCheckin(
    String type,
    Map<String, dynamic> body,
  ) =>
      ApiClient.instance.post('engagement/checkin/$type', body);
}
