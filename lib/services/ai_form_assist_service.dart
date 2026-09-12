import 'api_client.dart';

class AiFormAssistService {
  const AiFormAssistService();

  Future<Map<String, dynamic>> generate({
    required String module,
    required String topic,
    Map<String, dynamic> context = const <String, dynamic>{},
  }) async {
    dynamic response = await ApiClient.instance.post(
      'ai/form-assist',
      <String, dynamic>{
        'module': module,
        'topic': topic.trim(),
        'context': context,
      },
    );

    if (response is Map && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }

    return <String, dynamic>{};
  }
}
