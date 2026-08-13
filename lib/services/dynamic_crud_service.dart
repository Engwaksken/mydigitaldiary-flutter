import 'api_client.dart';
import '../models/dynamic_item.dart';

/// One service class instead of seventeen near-identical ones —
/// parameterized by [endpoint] (e.g. 'plans', 'diet-logs') rather than a
/// hardcoded path, matching how ApiCrudController on the Laravel side is
/// one base class every Api\{Module}Controller extends by setting $model.
class DynamicCrudService {
  final String endpoint;
  final _api = ApiClient.instance;

  DynamicCrudService(this.endpoint);

  /// [archived] mirrors ApiCrudController::index()'s ?archived= query
  /// param — false (the default) shows the normal list; true shows
  /// ONLY archived items, for a dedicated "Archived" view.
  Future<List<DynamicItem>> list({bool archived = false}) async {
    final response = await _api.get('$endpoint?archived=${archived ? 1 : 0}', cacheable: true);
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(DynamicItem.fromJson).toList();
  }

  Future<DynamicItem> create(Map<String, dynamic> data) async {
    final response = await _api.post(endpoint, data);
    return DynamicItem.fromJson(response as Map<String, dynamic>);
  }

  Future<DynamicItem> update(int id, Map<String, dynamic> data) async {
    final response = await _api.put('$endpoint/$id', data);
    return DynamicItem.fromJson(response as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('$endpoint/$id');

  Future<void> archive(int id) => _api.post('$endpoint/$id/archive', {});

  Future<void> unarchive(int id) => _api.post('$endpoint/$id/unarchive', {});

  Future<Map<String, dynamic>> stats() async {
    final response = await _api.get('$endpoint/stats');
    return Map<String, dynamic>.from(response);
  }

  Future<List<int>> downloadPdfBytes() => _api.downloadBytes('$endpoint/report/pdf');
}
