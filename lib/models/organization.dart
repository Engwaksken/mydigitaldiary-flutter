class OrganizationMemberInfo {
  final int id;
  final String email;
  final String role;
  final String status;

  OrganizationMemberInfo(
      {required this.id,
      required this.email,
      required this.role,
      required this.status});

  factory OrganizationMemberInfo.fromJson(Map<String, dynamic> json) =>
      OrganizationMemberInfo(
        id: json['id'],
        email: json['email'] ?? '',
        role: json['role'] ?? 'staff',
        status: json['status'] ?? 'invited',
      );
}

class OrganizationInfo {
  final int id;
  final String name;
  final String? planName;
  final String? planCategory;
  final int seatsUsed;
  final int seatLimit;
  final int remainingSeats;
  final List<OrganizationMemberInfo> members;

  OrganizationInfo({
    required this.id,
    required this.name,
    this.planName,
    this.planCategory,
    required this.seatsUsed,
    required this.seatLimit,
    required this.remainingSeats,
    required this.members,
  });

  bool get isFamilyTeam => planCategory == 'family_team';

  factory OrganizationInfo.fromJson(Map<String, dynamic> json) =>
      OrganizationInfo(
        id: json['id'],
        name: json['name'] ?? '',
        planName: json['plan_name'],
        planCategory: json['plan_category'],
        seatsUsed: json['seats_used'] ?? 0,
        seatLimit: json['seat_limit'] ?? 0,
        remainingSeats: json['remaining_seats'] ?? 0,
        members: json['members'] != null
            ? List<Map<String, dynamic>>.from(json['members'])
                .map(OrganizationMemberInfo.fromJson)
                .toList()
            : [],
      );
}
