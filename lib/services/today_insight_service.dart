import '../models/today_insight.dart';
import 'api_client.dart';

class TodayInsightService {
  const TodayInsightService();

  // Always request the server-generated insight without a Flutter response
  // cache. Laravel is authoritative for personalised currency conversion and
  // includes the user's preferred currency in its insight cache key.
  Future<TodayInsight> get() =>
      _load('dashboard/today-insight', false);

  Future<TodayInsight> refresh() =>
      _load('dashboard/today-insight/refresh', true);

  Future<TodayInsight> _load(String path, bool post) async {
    dynamic response = post
        ? await ApiClient.instance.post(path, const {})
        : await ApiClient.instance.get(path, cacheable: false);
    if (response is Map && response['data'] is Map) response = response['data'];
    if (response is! Map) throw ApiException(500, 'Invalid insight response.');
    return TodayInsight.fromJson(Map<String, dynamic>.from(response));
  }
}
