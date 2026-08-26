
class WorkspaceMember {
  final int? membershipId;
  final int userId;
  final String name;
  final String email;
  final String role;
  final String status;

  const WorkspaceMember({
    this.membershipId,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) {
    return WorkspaceMember(
      membershipId: _asInt(json['membership_id']),
      userId: _asInt(json['user_id']) ?? 0,
      name: (json['name'] ?? 'Member').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'member').toString(),
      status: (json['status'] ?? 'active').toString(),
    );
  }
}

class WorkspaceSharedItem {
  final int id;
  final String title;
  final String itemType;
  final String permission;
  final String? sharedByName;

  const WorkspaceSharedItem({
    required this.id,
    required this.title,
    required this.itemType,
    required this.permission,
    this.sharedByName,
  });

  factory WorkspaceSharedItem.fromJson(Map<String, dynamic> json) {
    final sharedBy = json['shared_by'];

    return WorkspaceSharedItem(
      id: _asInt(json['id']) ?? 0,
      title: (json['title'] ?? json['item_type'] ?? 'Shared item').toString(),
      itemType: (json['item_type'] ?? 'item').toString(),
      permission: (json['permission'] ?? 'view').toString(),
      sharedByName: sharedBy is Map ? sharedBy['name']?.toString() : null,
    );
  }
}

class WorkspaceFile {
  final int id;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final String permission;
  final String? uploaderName;
  final String? downloadUrl;

  const WorkspaceFile({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.permission,
    this.uploaderName,
    this.downloadUrl,
  });

  factory WorkspaceFile.fromJson(Map<String, dynamic> json) {
    final uploader = json['uploader'];

    return WorkspaceFile(
      id: _asInt(json['id']) ?? 0,
      name: (json['original_name'] ?? json['name'] ?? 'File').toString(),
      mimeType: (json['mime_type'] ?? '').toString(),
      sizeBytes: _asInt(json['size_bytes']) ?? 0,
      permission: (json['permission'] ?? 'view').toString(),
      uploaderName: uploader is Map ? uploader['name']?.toString() : null,
      downloadUrl: json['download_url']?.toString(),
    );
  }

  String get humanSize {
    final bytes = sizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class WorkspaceActivity {
  final int id;
  final String event;
  final String actorName;
  final DateTime? createdAt;

  const WorkspaceActivity({
    required this.id,
    required this.event,
    required this.actorName,
    required this.createdAt,
  });

  factory WorkspaceActivity.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];

    return WorkspaceActivity(
      id: _asInt(json['id']) ?? 0,
      event: (json['event'] ?? 'activity').toString(),
      actorName: actor is Map ? (actor['name'] ?? 'System').toString() : 'System',
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  String get label {
    final words = event.replaceAll('_', ' ').split(' ');
    return words
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class WorkspaceOverview {
  final bool enabled;
  final int? organizationId;
  final String organizationName;
  final String role;
  final bool canManageMembers;
  final int membersCount;
  final List<WorkspaceMember> members;
  final List<WorkspaceSharedItem> sharedItems;
  final List<WorkspaceFile> files;
  final List<WorkspaceActivity> activity;

  const WorkspaceOverview({
    required this.enabled,
    this.organizationId,
    required this.organizationName,
    required this.role,
    required this.canManageMembers,
    required this.membersCount,
    required this.members,
    required this.sharedItems,
    required this.files,
    required this.activity,
  });

  factory WorkspaceOverview.fromJson(Map<String, dynamic> json) {
    final organization = json['organization'];
    final org = organization is Map
        ? Map<String, dynamic>.from(organization)
        : <String, dynamic>{};

    List<T> parseList<T>(
      dynamic value,
      T Function(Map<String, dynamic>) parser,
    ) {
      if (value is! List) return <T>[];

      return value
          .whereType<Map>()
          .map((item) => parser(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    return WorkspaceOverview(
      enabled: json['enabled'] == true,
      organizationId: _asInt(org['id']),
      organizationName:
          (org['name'] ?? 'Shared Workspace').toString(),
      role: (json['role'] ?? 'member').toString(),
      canManageMembers: json['can_manage_members'] == true,
      membersCount: _asInt(json['members_count']) ?? 0,
      members: parseList(json['members'], WorkspaceMember.fromJson),
      sharedItems:
          parseList(json['shared_items'], WorkspaceSharedItem.fromJson),
      files: parseList(json['files'], WorkspaceFile.fromJson),
      activity: parseList(json['activity'], WorkspaceActivity.fromJson),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
