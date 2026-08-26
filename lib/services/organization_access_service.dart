import 'api_client.dart';

class OrganizationAccessContext {
  final bool managedByOwner;
  final bool isWorkspaceOwner;
  final bool hasActiveAccess;
  final int? organizationId;
  final String organizationName;
  final String organizationRole;
  final int? ownerUserId;
  final String ownerName;

  const OrganizationAccessContext({
    required this.managedByOwner,
    required this.isWorkspaceOwner,
    required this.hasActiveAccess,
    required this.organizationId,
    required this.organizationName,
    required this.organizationRole,
    required this.ownerUserId,
    required this.ownerName,
  });

  factory OrganizationAccessContext.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationAccessContext(
      managedByOwner: json['managed_by_owner'] == true,
      isWorkspaceOwner: json['is_workspace_owner'] == true,
      hasActiveAccess: json['has_active_access'] == true,
      organizationId: _asInt(json['organization_id']),
      organizationName:
          (json['organization_name'] ?? '').toString(),
      organizationRole:
          (json['organization_role'] ?? '').toString(),
      ownerUserId: _asInt(json['owner_user_id']),
      ownerName: (json['owner_name'] ?? '').toString(),
    );
  }

  bool get canManageMembers => isWorkspaceOwner;

  bool get canManageBilling => !managedByOwner;

  bool get canUseTeamChat => organizationId != null;

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class OrganizationAccessService {
  final ApiClient _api;

  OrganizationAccessService({
    ApiClient? api,
  }) : _api = api ?? ApiClient.instance;

  Future<OrganizationAccessContext> context() async {
    final response = await _api.get(
      'organization/access-context',
      cacheable: false,
    );

    final root = response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{};

    final raw = root['data'];

    if (raw is! Map) {
      throw ApiException(
        500,
        (root['message'] ??
                'Could not load organisation access.')
            .toString(),
      );
    }

    return OrganizationAccessContext.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }
}
