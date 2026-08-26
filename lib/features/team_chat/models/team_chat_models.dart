class TeamConversation {
  final int id;
  final String type;
  final String name;
  final String description;
  final bool isGeneral;
  final bool isAnnouncementOnly;
  final int unreadCount;
  final TeamLastMessage? lastMessage;

  const TeamConversation({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.isGeneral,
    required this.isAnnouncementOnly,
    required this.unreadCount,
    required this.lastMessage,
  });

  factory TeamConversation.fromJson(Map<String, dynamic> json) {
    return TeamConversation(
      id: _int(json['id']),
      type: (json['type'] ?? 'channel').toString(),
      name: (json['name'] ?? 'Conversation').toString(),
      description: (json['description'] ?? '').toString(),
      isGeneral: json['is_general'] == true,
      isAnnouncementOnly: json['is_announcement_only'] == true,
      unreadCount: _int(json['unread_count']),
      lastMessage: json['last_message'] is Map
          ? TeamLastMessage.fromJson(
              Map<String, dynamic>.from(json['last_message'] as Map),
            )
          : null,
    );
  }
}

class TeamLastMessage {
  final String body;
  final String senderName;
  final DateTime? createdAt;

  const TeamLastMessage({
    required this.body,
    required this.senderName,
    required this.createdAt,
  });

  factory TeamLastMessage.fromJson(Map<String, dynamic> json) {
    return TeamLastMessage(
      body: (json['body'] ?? '').toString(),
      senderName: (json['sender_name'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}

class TeamChatMember {
  final int userId;
  final String name;
  final String email;
  final String role;

  const TeamChatMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  factory TeamChatMember.fromJson(Map<String, dynamic> json) {
    return TeamChatMember(
      userId: _int(json['user_id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'member').toString(),
    );
  }
}

class TeamChatAttachment {
  final int id;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final String downloadPath;

  const TeamChatAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.downloadPath,
  });

  factory TeamChatAttachment.fromJson(Map<String, dynamic> json) {
    return TeamChatAttachment(
      id: _int(json['id']),
      name: (json['name'] ?? 'Attachment').toString(),
      mimeType: (json['mime_type'] ?? '').toString(),
      sizeBytes: _int(json['size_bytes']),
      downloadPath: (json['download_path'] ?? '').toString(),
    );
  }
}

class TeamChatMessage {
  final int id;
  final int userId;
  final String senderName;
  final String body;
  final bool isAnnouncement;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final List<TeamChatAttachment> attachments;
  final List<Map<String, dynamic>> reactions;
  final Map<String, dynamic>? replyTo;

  const TeamChatMessage({
    required this.id,
    required this.userId,
    required this.senderName,
    required this.body,
    required this.isAnnouncement,
    required this.createdAt,
    required this.editedAt,
    required this.attachments,
    required this.reactions,
    required this.replyTo,
  });

  factory TeamChatMessage.fromJson(Map<String, dynamic> json) {
    return TeamChatMessage(
      id: _int(json['id']),
      userId: _int(json['user_id']),
      senderName: (json['sender_name'] ?? 'Member').toString(),
      body: (json['body'] ?? '').toString(),
      isAnnouncement: json['is_announcement'] == true,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      editedAt: DateTime.tryParse((json['edited_at'] ?? '').toString()),
      attachments: _maps(json['attachments'])
          .map(TeamChatAttachment.fromJson)
          .toList(growable: false),
      reactions: _maps(json['reactions']),
      replyTo: json['reply_to'] is Map
          ? Map<String, dynamic>.from(json['reply_to'] as Map)
          : null,
    );
  }
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
