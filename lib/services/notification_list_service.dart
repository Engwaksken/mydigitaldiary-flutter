import '../models/notification.dart';
import 'api_client.dart';

class NotificationListService {
  final _api = ApiClient.instance;

  Future<List<AppNotification>> list() async {
    final response = await _api.get('notifications');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(AppNotification.fromJson).toList();
  }

  Future<void> markRead(String id) => _api.post('notifications/$id/read', {});

  Future<void> markAllRead() => _api.post('notifications/read-all', {});
}
