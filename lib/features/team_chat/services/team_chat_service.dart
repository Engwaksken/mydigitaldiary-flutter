import 'package:file_picker/file_picker.dart';

import '../../../services/api_client.dart';
import '../models/team_chat_models.dart';

class TeamChatService {
  final ApiClient _api;

  TeamChatService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Future<List<TeamConversation>> conversations() async {
    final response = await _api.get(
      'team-chat/conversations',
      cacheable: false,
    );

    final root = _map(response);
    final data = _map(root['data']);
    final items = data['conversations'];

    if (items is! List) return const [];

    return items
        .whereType<Map>()
        .map(
          (item) => TeamConversation.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<TeamChatThread> thread(int conversationId) async {
    final response = await _api.get(
      'team-chat/conversations/$conversationId',
      cacheable: false,
    );

    final root = _map(response);
    final data = _map(root['data']);

    return TeamChatThread.fromJson(data);
  }

  Future<String> send({
    required int conversationId,
    required String body,
    int? replyToId,
    bool isAnnouncement = false,
    bool notifyAll = false,
    List<int> mentionUserIds = const [],
    List<PlatformFile> attachments = const [],
  }) async {
    /*
     * If ApiClient exposes multipart(), use the block below. The call is kept
     * separate from normal JSON so protected document uploads remain binary.
     */
    if (attachments.isNotEmpty) {
      final response = await _api.multipart(
        'team-chat/conversations/$conversationId/messages',
        fields: {
          'body': body,
          if (replyToId != null) 'reply_to_id': '$replyToId',
          'is_announcement': isAnnouncement ? '1' : '0',
          'notify_all': notifyAll ? '1' : '0',
          for (var i = 0; i < mentionUserIds.length; i++)
            'mention_user_ids[$i]': '${mentionUserIds[i]}',
        },
        files: attachments
            .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
            .map(
              (file) => MultipartUploadFile(
                fieldName: 'attachments[]',
                bytes: file.bytes!,
                fileName: file.name,
              ),
            )
            .toList(growable: false),
      );

      return _message(response, 'Message sent.');
    }

    final response = await _api.post(
      'team-chat/conversations/$conversationId/messages',
      {
        'body': body,
        if (replyToId != null) 'reply_to_id': replyToId,
        'is_announcement': isAnnouncement,
        'notify_all': notifyAll,
        'mention_user_ids': mentionUserIds,
      },
    );

    return _message(response, 'Message sent.');
  }

  Future<void> react(int messageId, String reaction) async {
    await _api.post(
      'team-chat/messages/$messageId/reaction',
      {'reaction': reaction},
    );
  }

  Future<void> deleteMessage(int messageId) async {
    await _api.delete('team-chat/messages/$messageId');
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  String _message(dynamic value, String fallback) {
    if (value is Map && value['message'] != null) {
      return value['message'].toString();
    }
    return fallback;
  }
}

class TeamChatThread {
  final TeamConversation conversation;
  final bool canManage;
  final List<TeamChatMember> members;
  final List<TeamChatMessage> messages;

  const TeamChatThread({
    required this.conversation,
    required this.canManage,
    required this.members,
    required this.messages,
  });

  factory TeamChatThread.fromJson(Map<String, dynamic> json) {
    return TeamChatThread(
      conversation: TeamConversation.fromJson(
        Map<String, dynamic>.from(
          (json['conversation'] as Map?) ?? const {},
        ),
      ),
      canManage: json['can_manage'] == true,
      members: _mapList(
        json['members'],
        TeamChatMember.fromJson,
      ),
      messages: _mapList(
        json['messages'],
        TeamChatMessage.fromJson,
      ).reversed.toList(growable: false),
    );
  }
}

List<T> _mapList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) parser,
) {
  if (value is! List) return <T>[];

  return value
      .whereType<Map>()
      .map(
        (item) => parser(
          Map<String, dynamic>.from(item),
        ),
      )
      .toList(growable: false);
}
