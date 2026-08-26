class WorkspaceManagedMember {
  final int membershipId;
  final int? userId;
  final String name;
  final String email;
  final String role;
  final String status;
  final bool isPending;

  const WorkspaceManagedMember({
    required this.membershipId,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.isPending,
  });

  factory WorkspaceManagedMember.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkspaceManagedMember(
      membershipId: _asInt(
            json['membership_id'] ?? json['id'],
          ) ??
          0,
      userId: _asInt(json['user_id']),
      name: (json['name'] ?? json['email'] ?? 'Member').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'member').toString(),
      status: (json['status'] ?? 'active').toString(),
      isPending: json['is_pending'] == true ||
          (json['status'] ?? '').toString().toLowerCase() == 'invited',
    );
  }

  bool get isInactive =>
      ['inactive', 'suspended'].contains(status.toLowerCase());

  bool get isActive => status.toLowerCase() == 'active';
}

class WorkspaceMemberManagement {
  final int organizationId;
  final String organizationName;
  final String planName;
  final int seatLimit;
  final int seatsUsed;
  final int remainingSeats;
  final List<WorkspaceManagedMember> members;

  const WorkspaceMemberManagement({
    required this.organizationId,
    required this.organizationName,
    required this.planName,
    required this.seatLimit,
    required this.seatsUsed,
    required this.remainingSeats,
    required this.members,
  });

  factory WorkspaceMemberManagement.fromJson(
    Map<String, dynamic> json,
  ) {
    final organization = json['organization'] is Map
        ? Map<String, dynamic>.from(json['organization'] as Map)
        : <String, dynamic>{};

    return WorkspaceMemberManagement(
      organizationId:
          _asInt(organization['id'] ?? json['id']) ?? 0,
      organizationName:
          (organization['name'] ?? json['name'] ?? 'Workspace').toString(),
      planName:
          (json['plan_name'] ?? 'Team subscription').toString(),
      seatLimit: _asInt(json['seat_limit']) ?? 0,
      seatsUsed: _asInt(json['seats_used']) ?? 0,
      remainingSeats: _asInt(json['remaining_seats']) ??
          ((_asInt(json['seat_limit']) ?? 0) -
                  (_asInt(json['seats_used']) ?? 0))
              .clamp(0, 999999),
      members: _mapList(
        json['members'],
        WorkspaceManagedMember.fromJson,
      ),
    );
  }

  bool get hasSeatAvailable =>
      seatLimit <= 0 || remainingSeats > 0;
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

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
