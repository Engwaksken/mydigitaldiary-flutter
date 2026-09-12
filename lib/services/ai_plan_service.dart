import '../models/ai_plan.dart';
import 'api_client.dart';

class AiPlanService {
  final _api = ApiClient.instance;

  Future<List<AiPlan>> list() async {
    final response = await _api.get('ai-plans');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(AiPlan.fromJson).toList();
  }

  Future<AiPlan> generate({String? customPrompt}) async {
    // DateTime.now() (not .toUtc()) is intentional — this should be
    // exactly what the phone's own clock shows right now, since
    // that's what "today" and "next 7 days" mean to the person
    // holding it, regardless of which timezone that technically
    // corresponds to on the server.
    final response = await _api.post('ai-plans', {
      'client_datetime': DateTime.now().toIso8601String(),
      if (customPrompt != null && customPrompt.trim().isNotEmpty)
        'custom_prompt': customPrompt.trim(),
    });
    return AiPlan.fromJson(response['data']);
  }

  Future<void> delete(int id) => _api.delete('ai-plans/$id');
}
