import '../models/reminder.dart';
import 'api_client.dart';

/// The pattern every other module's service follows: list (paginated —
/// Laravel's paginate() JSON shape has the actual rows under 'data'),
/// create, update, delete. Copy this file, rename, point at a different
/// endpoint/model for Meetings, Expenses, Income, Plans, etc.
class ReminderService {
  final _api = ApiClient.instance;

  Future<List<Reminder>> list() async {
    final response = await _api.get('reminders', cacheable: true);
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(Reminder.fromJson).toList();
  }

  Future<Reminder> create(Reminder reminder, {List<int>? itemIds}) async {
    final response = await _api.post('reminders',
        {...reminder.toJson(), if (itemIds != null) 'item_ids': itemIds});
    return Reminder.fromJson(response);
  }

  Future<Reminder> update(int id, Reminder reminder,
      {List<int>? itemIds}) async {
    final response = await _api.put('reminders/$id',
        {...reminder.toJson(), if (itemIds != null) 'item_ids': itemIds});
    return Reminder.fromJson(response);
  }

  /// Powers the "which specific item(s)" picker — refetched whenever
  /// the Related Module selection changes, same as the web app's AJAX
  /// call behind its own version of this picker.
  Future<List<Map<String, dynamic>>> itemsForModule(String module) async {
    if (module.isEmpty) return [];
    final response = await _api.get(
        'reminders/items-for-module?module=${Uri.encodeQueryComponent(module)}');
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> delete(int id) => _api.delete('reminders/$id');
}
