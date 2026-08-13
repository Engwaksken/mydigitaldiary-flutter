import '../models/expense.dart';
import 'api_client.dart';

class ExpenseService {
  final _api = ApiClient.instance;

  Future<List<Expense>> list() async {
    final response = await _api.get('expenses', cacheable: true);
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(Expense.fromJson).toList();
  }

  Future<Expense> create(Expense expense) async {
    final response = await _api.post('expenses', expense.toJson(includeItems: true));
    return Expense.fromJson(response);
  }

  Future<Expense> update(int id, Expense expense) async {
    final response = await _api.put('expenses/$id', expense.toJson(includeItems: true));
    return Expense.fromJson(response);
  }

  Future<void> delete(int id) => _api.delete('expenses/$id');
}
