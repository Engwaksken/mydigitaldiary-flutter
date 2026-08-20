import 'api_client.dart';

class AccountDataService {
  Future<Map<String, dynamic>> usage() async {
    final raw = await ApiClient.instance.get('account-data/usage');
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<List<Map<String, dynamic>>> trash() async {
    final raw = await ApiClient.instance.get('account-data/trash');
    final map = Map<String, dynamic>.from(raw as Map);
    return (map['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> restore(int id) async {
    await ApiClient.instance.post('account-data/trash/$id/restore', const {});
  }

  Future<void> deleteForever(int id) async {
    await ApiClient.instance.delete('account-data/trash/$id');
  }
}
