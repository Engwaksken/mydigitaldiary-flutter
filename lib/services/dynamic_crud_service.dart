import 'api_client.dart';
import 'offline_mutation_queue.dart';
import '../models/dynamic_item.dart';

class DynamicCrudService {
  final String endpoint;
  final _api = ApiClient.instance;
  final _offline = OfflineMutationQueue.instance;

  DynamicCrudService(this.endpoint);

  bool get offlineEnabled => endpoint == 'notes' || endpoint == 'project-tasks';
  String get _moduleLabel => endpoint == 'notes'
      ? 'Notes'
      : endpoint == 'project-tasks'
          ? 'Tasks'
          : endpoint;

  Future<List<DynamicItem>> list(
      {bool archived = false,
      String? search,
      String? period,
      DateTime? from,
      DateTime? to,
      int page = 1,
      Map<String, String> extra = const {}}) async {
    final params = <String>['archived=${archived ? 1 : 0}', 'page=$page'];
    if (search != null && search.trim().isNotEmpty) {
      params.add('q=${Uri.encodeQueryComponent(search.trim())}');
    }
    if (period != null && period.isNotEmpty) params.add('period=$period');
    if (from != null) {
      params.add('from=${from.toIso8601String().split('T').first}');
    }
    if (to != null) params.add('to=${to.toIso8601String().split('T').first}');
    extra.forEach((key, value) {
      if (value.isNotEmpty) {
        params.add(
            '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}');
      }
    });
    dynamic response;
    try {
      response =
          await _api.get('$endpoint?${params.join('&')}', cacheable: true);
    } catch (e) {
      if (!offlineEnabled || !ApiClient.isTransientNetworkError(e)) rethrow;
      response = <String, dynamic>{'data': <Map<String, dynamic>>[]};
    }
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    var items = rows.map(DynamicItem.fromJson).toList();
    if (offlineEnabled &&
        !archived &&
        page == 1 &&
        (search == null || search.trim().isEmpty) &&
        (period == null || period.isEmpty)) {
      items = await _applyOfflineOverlay(items);
    }
    return items;
  }

  Future<List<DynamicItem>> _applyOfflineOverlay(
      List<DynamicItem> server) async {
    final byId = <int, Map<String, dynamic>>{
      for (final item in server) item.id: Map<String, dynamic>.from(item.data)
    };
    final order = server.map((e) => e.id).toList();
    final pending = await _offline.forPrefix(endpoint);
    for (final mutation in pending) {
      if (mutation.method == 'POST' &&
          mutation.path == endpoint &&
          mutation.localId != null) {
        final data = {
          ...mutation.body,
          'id': mutation.localId,
          '_offline_pending': true
        };
        byId[mutation.localId!] = data;
        if (!order.contains(mutation.localId)) {
          order.insert(0, mutation.localId!);
        }
        continue;
      }
      final id = int.tryParse(mutation.path.split('/').last);
      if (id == null) continue;
      if (mutation.method == 'DELETE') {
        byId.remove(id);
        order.remove(id);
      } else if (mutation.method == 'PUT' || mutation.method == 'PATCH') {
        final current = byId[id] ?? <String, dynamic>{'id': id};
        byId[id] = {...current, ...mutation.body, '_offline_pending': true};
        if (!order.contains(id)) order.insert(0, id);
      }
    }
    return order
        .where(byId.containsKey)
        .map((id) => DynamicItem(byId[id]!))
        .toList();
  }

  Future<DynamicItem> create(Map<String, dynamic> data) async {
    try {
      final response = await _api.post(endpoint, data);
      return DynamicItem.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      if (!offlineEnabled || !ApiClient.isTransientNetworkError(e)) rethrow;
      final localId = _offline.newLocalId();
      await _offline.enqueue(
        method: 'POST',
        path: endpoint,
        body: data,
        module: _moduleLabel,
        label: 'Create ${_moduleLabel.toLowerCase()} item',
        localId: localId,
      );
      return DynamicItem({...data, 'id': localId, '_offline_pending': true});
    }
  }

  Future<DynamicItem> update(int id, Map<String, dynamic> data,
      {String? baseUpdatedAt}) async {
    if (offlineEnabled && id < 0) {
      await _offline.updateQueuedCreate(id, data);
      return DynamicItem({...data, 'id': id, '_offline_pending': true});
    }
    try {
      final response = await _api.put('$endpoint/$id', data);
      return DynamicItem.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      if (!offlineEnabled || !ApiClient.isTransientNetworkError(e)) rethrow;
      await _offline.enqueue(
        method: 'PUT',
        path: '$endpoint/$id',
        body: data,
        module: _moduleLabel,
        label: 'Update ${_moduleLabel.toLowerCase()} item',
        baseUpdatedAt: baseUpdatedAt,
      );
      return DynamicItem({
        ...data,
        'id': id,
        'updated_at': baseUpdatedAt,
        '_offline_pending': true
      });
    }
  }

  Future<void> delete(int id, {String? baseUpdatedAt}) async {
    if (offlineEnabled && id < 0) {
      await _offline.removeLocalCreate(id);
      return;
    }
    try {
      await _api.delete('$endpoint/$id');
    } catch (e) {
      if (!offlineEnabled || !ApiClient.isTransientNetworkError(e)) rethrow;
      await _offline.enqueue(
        method: 'DELETE',
        path: '$endpoint/$id',
        body: const {},
        module: _moduleLabel,
        label: 'Delete ${_moduleLabel.toLowerCase()} item',
        baseUpdatedAt: baseUpdatedAt,
      );
    }
  }

  Future<void> bulkDelete(List<int> ids) =>
      _api.post('$endpoint/bulk-delete', {'ids': ids});
  Future<void> archive(int id) => _api.post('$endpoint/$id/archive', {});
  Future<void> unarchive(int id) => _api.post('$endpoint/$id/unarchive', {});

  Future<Map<String, dynamic>> stats() async {
    final response = await _api.get('$endpoint/stats');
    return Map<String, dynamic>.from(response);
  }

  Future<List<int>> downloadPdfBytes() =>
      _api.downloadBytes('$endpoint/report/pdf');
}
