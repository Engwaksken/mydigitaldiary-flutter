import 'api_client.dart';

class PrivacyService {
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> status() async =>
      Map<String, dynamic>.from((await _api.get('privacy'))['data']);

  Future<Map<String, dynamic>> requestReport({
    required String reason,
    required List<String> modules,
    DateTime? from,
    DateTime? to,
  }) async =>
      Map<String, dynamic>.from(await _api.post('privacy/reports', {
        'reason': reason,
        'modules': modules,
        if (from != null) 'date_from': _d(from),
        if (to != null) 'date_to': _d(to),
      }));

  Future<Map<String, dynamic>> scheduleDeletion({
    required String password,
    required String reason,
    bool backup = true,
  }) async =>
      Map<String, dynamic>.from(await _api.deleteWithBody('privacy/account', {
        'password': password,
        'reason': reason,
        'backup': backup,
        'confirm_delete': '1',
      }));

  Future<void> cancelDeletion() =>
      _api.post('privacy/account/cancel-deletion', {});

  String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
