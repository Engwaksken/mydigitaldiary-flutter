import 'api_client.dart';

class GoalLinkOption {
  final int id;
  final String title;
  final String module;
  const GoalLinkOption(
      {required this.id, required this.title, required this.module});
  factory GoalLinkOption.fromJson(Map<String, dynamic> j) => GoalLinkOption(
      id: (j['id'] as num).toInt(),
      title: j['title']?.toString() ?? 'Goal',
      module: j['module']?.toString() ?? 'personal');
}

class GoalLinkService {
  Future<List<GoalLinkOption>> activeGoals() async {
    final raw = await ApiClient.instance.get('personal-goals', cacheable: true);
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final rows = map['data'] is List
        ? map['data'] as List
        : (raw is List ? raw : const []);
    return rows
        .whereType<Map>()
        .map((e) => GoalLinkOption.fromJson(Map<String, dynamic>.from(e)))
        .where((g) => g.title.trim().isNotEmpty)
        .toList();
  }
}
