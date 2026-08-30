import '../models/today_insight.dart';
import 'api_client.dart';

class TodayInsightService {
  const TodayInsightService();

  Future<TodayInsight> get() {
    return _load(
      path: 'dashboard/today-insight',
      refresh: false,
    );
  }

  Future<TodayInsight> refresh() {
    return _load(
      path: 'dashboard/today-insight/refresh',
      refresh: true,
    );
  }

  Future<TodayInsight> _load({
    required String path,
    required bool refresh,
  }) async {
    dynamic response = refresh
        ? await ApiClient.instance.post(path, const <String, dynamic>{})
        : await ApiClient.instance.get(path, cacheable: false);

    if (response is Map && response['data'] is Map) {
      response = response['data'];
    }

    if (response is! Map) {
      throw ApiException(500, 'Today’s Insight returned an invalid response.');
    }

    final insight = TodayInsight.fromJson(
      Map<String, dynamic>.from(response),
    );

    if (insight.title.trim().isEmpty ||
        insight.message.trim().isEmpty) {
      throw ApiException(
        500,
        'Today’s Insight response was incomplete.',
      );
    }

    return insight;
  }
}
