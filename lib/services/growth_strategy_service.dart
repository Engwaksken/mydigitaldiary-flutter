import 'api_client.dart';

class GrowthStrategyService {
  const GrowthStrategyService();

  Future<Map<String, dynamic>> dashboard() async {
    final response =
        await ApiClient.instance.get('growth/dashboard', cacheable: false);
    return _unwrap(response);
  }

  Future<Map<String, dynamic>> joinChallenge() async {
    final response = await ApiClient.instance
        .post('growth/challenge/join', <String, dynamic>{});
    return _unwrap(response);
  }

  Future<Map<String, dynamic>> createReferral(
      {String channel = 'mobile'}) async {
    final response = await ApiClient.instance
        .post('growth/referral', <String, dynamic>{'channel': channel});
    return _unwrap(response);
  }

  Future<void> track(String eventName,
      {String source = 'mobile', Map<String, dynamic>? meta}) async {
    await ApiClient.instance.post('growth/track', <String, dynamic>{
      'event_name': eventName,
      'source': source,
      if (meta != null && meta.isNotEmpty) 'meta': meta,
    });
  }

  Map<String, dynamic> _unwrap(dynamic response) {
    if (response is Map && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    return <String, dynamic>{};
  }
}
