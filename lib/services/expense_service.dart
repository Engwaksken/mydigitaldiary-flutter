import '../models/expense.dart';
import 'api_client.dart';
import 'offline_mutation_queue.dart';

class ExpenseService {
  final _api = ApiClient.instance;
  final _offline = OfflineMutationQueue.instance;

  Future<List<Expense>> list() async {
    dynamic response;
    try {
      response = await _api.get('expenses', cacheable: true);
    } catch (e) {
      if (!ApiClient.isTransientNetworkError(e)) rethrow;
      response = <String, dynamic>{'data': <Map<String, dynamic>>[]};
    }
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    var items = rows.map(Expense.fromJson).toList();
    final pending = await _offline.forPrefix('expenses');
    final byId = <int, Map<String, dynamic>>{for (final e in items) e.id: {
      ...e.toJson(includeItems: true),
      'id': e.id,
      'updated_at': e.updatedAt?.toIso8601String(),
    }};
    final order = items.map((e) => e.id).toList();
    for (final m in pending) {
      if (m.method == 'POST' && m.path == 'expenses' && m.localId != null) {
        byId[m.localId!] = {...m.body, 'id': m.localId, '_offline_pending': true};
        if (!order.contains(m.localId)) order.insert(0, m.localId!);
        continue;
      }
      final id = int.tryParse(m.path.split('/').last);
      if (id == null) continue;
      if (m.method == 'DELETE') {
        byId.remove(id); order.remove(id);
      } else if (m.method == 'PUT') {
        byId[id] = {...(byId[id] ?? {'id': id}), ...m.body, '_offline_pending': true};
        if (!order.contains(id)) order.insert(0, id);
      }
    }
    return order.where(byId.containsKey).map((id) => Expense.fromJson(byId[id]!)).toList();
  }

  Future<Expense> create(Expense expense) async {
    final body = expense.toJson(includeItems: true);
    try {
      final response = await _api.post('expenses', body);
      return Expense.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      if (!ApiClient.isTransientNetworkError(e)) rethrow;
      final localId = _offline.newLocalId();
      await _offline.enqueue(method: 'POST', path: 'expenses', body: body, module: 'Expenses', label: 'Create expense', localId: localId);
      return Expense.fromJson({...body, 'id': localId, '_offline_pending': true});
    }
  }

  Future<Expense> update(int id, Expense expense) async {
    final body = expense.toJson(includeItems: true);
    if (id < 0) {
      await _offline.updateQueuedCreate(id, body);
      return Expense.fromJson({...body, 'id': id, '_offline_pending': true});
    }
    try {
      final response = await _api.put('expenses/$id', body);
      return Expense.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      if (!ApiClient.isTransientNetworkError(e)) rethrow;
      await _offline.enqueue(
        method: 'PUT', path: 'expenses/$id', body: body, module: 'Expenses', label: 'Update expense',
        baseUpdatedAt: expense.updatedAt?.toUtc().toIso8601String(),
      );
      return Expense.fromJson({...body, 'id': id, 'updated_at': expense.updatedAt?.toIso8601String(), '_offline_pending': true});
    }
  }

  Future<Map<String, dynamic>> extractReceipt({required List<int> bytes, required String fileName, required String contentType}) async {
    final response = await _api.postMultipart('expenses', fileFieldName: 'receipt_file', fileBytes: bytes, fileName: fileName, contentType: contentType, fields: const {'receipt_extract': '1'});
    final map = Map<String, dynamic>.from(response as Map);
    return Map<String, dynamic>.from((map['data'] as Map?) ?? const {});
  }

  Future<void> delete(int id, {DateTime? updatedAt}) async {
    if (id < 0) { await _offline.removeLocalCreate(id); return; }
    try {
      await _api.delete('expenses/$id');
    } catch (e) {
      if (!ApiClient.isTransientNetworkError(e)) rethrow;
      await _offline.enqueue(
        method: 'DELETE', path: 'expenses/$id', body: const {}, module: 'Expenses', label: 'Delete expense',
        baseUpdatedAt: updatedAt?.toUtc().toIso8601String(),
      );
    }
  }

  Future<void> bulkDelete(List<int> ids) => _api.post('expenses/bulk-delete', {'ids': ids});
}
