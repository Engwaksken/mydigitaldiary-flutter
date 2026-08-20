import 'api_client.dart';

class SupportChatMessage {
  final int? id;
  final String senderType;
  final String message;
  final DateTime? createdAt;

  const SupportChatMessage({
    this.id,
    required this.senderType,
    required this.message,
    this.createdAt,
  });

  bool get isMine => senderType == 'user';
  bool get isAssistant => senderType == 'ai';

  factory SupportChatMessage.fromJson(Map<String, dynamic> json) {
    return SupportChatMessage(
      id: _toInt(json['id']),
      senderType: (json['sender_type'] ?? 'support').toString(),
      message: cleanChatText((json['message'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}

class SupportConversationData {
  final int? id;
  final bool humanAssigned;
  final String? assigneeName;
  final List<SupportChatMessage> messages;

  const SupportConversationData({
    this.id,
    required this.humanAssigned,
    this.assigneeName,
    required this.messages,
  });

  factory SupportConversationData.fromResponse(dynamic response) {
    final root = _map(response);
    final raw = root['data'] is Map ? _map(root['data']) : root;
    final assignedId = raw['assigned_to_user_id'];
    final assignee = raw['assignee'] is Map ? _map(raw['assignee']) : const <String, dynamic>{};
    final items = raw['messages'] is List ? raw['messages'] as List : const [];

    return SupportConversationData(
      id: _toInt(raw['id']),
      humanAssigned: assignedId != null || (raw['status']?.toString() == 'human'),
      assigneeName: (assignee['name'] ?? raw['assignee_name'])?.toString(),
      messages: items
          .whereType<Map>()
          .map((item) => SupportChatMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class SupportChatService {
  final ApiClient _api = ApiClient.instance;

  Future<SupportConversationData> load() async {
    final response = await _api.get('support');
    return SupportConversationData.fromResponse(response);
  }

  Future<SupportConversationData> send(String message) async {
    final response = await _api.post('support', {'message': message.trim()});
    return SupportConversationData.fromResponse(response);
  }
}

String cleanChatText(String input) {
  var text = input.trim();
  if (text.isEmpty) return text;

  // Fenced code markers. Keep the useful text inside the fence.
  text = text.replaceAll(RegExp(r'```[a-zA-Z0-9_+\-]*\s*'), '');
  text = text.replaceAll('```', '');

  // Markdown headings and quote markers.
  text = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');

  // Bold / italic / inline-code markers.
  text = text.replaceAll('**', '');
  text = text.replaceAll('__', '');
  text = text.replaceAll('`', '');
  text = text.replaceAllMapped(RegExp(r'(?<!\*)\*([^\n*]+)\*(?!\*)'), (m) => m.group(1) ?? '');
  text = text.replaceAllMapped(RegExp(r'(?<!_)_([^\n_]+)_(?!_)'), (m) => m.group(1) ?? '');

  // Markdown links -> readable label + URL.
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)', caseSensitive: false),
    (m) => '${m.group(1)} (${m.group(2)})',
  );

  // Unordered Markdown bullets -> plain chat bullets.
  text = text.replaceAllMapped(
    RegExp(r'^\s*[-*+]\s+', multiLine: true),
    (_) => '• ',
  );

  // Decorative horizontal rules and excessive whitespace.
  text = text.replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return text.trim();
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
