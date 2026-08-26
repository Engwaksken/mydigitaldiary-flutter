import 'api_client.dart';

class WorkspaceService {
  const WorkspaceService();

  Future<List<Map<String, dynamic>>> list() async {
    final response = await ApiClient.instance.get(
      'workspaces',
      cacheable: false,
    );

    dynamic raw = response;

    if (raw is Map && raw['data'] is List) {
      raw = raw['data'];
    }

    if (raw is! List) return <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> show(int workspaceId) async {
    final response = await ApiClient.instance.get(
      'workspaces/$workspaceId',
      cacheable: false,
    );

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);

      if (map['data'] is Map) {
        return Map<String, dynamic>.from(map['data']);
      }

      return map;
    }

    return <String, dynamic>{};
  }
}
