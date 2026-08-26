import '../services/organization_access_service.dart';

class MobileNavigationVisibility {
  final bool showManageMembers;
  final bool showBilling;
  final bool showTeamChat;

  const MobileNavigationVisibility({
    required this.showManageMembers,
    required this.showBilling,
    required this.showTeamChat,
  });

  factory MobileNavigationVisibility.fromAccess(
    OrganizationAccessContext access,
  ) {
    return MobileNavigationVisibility(
      showManageMembers: access.canManageMembers,
      showBilling: access.canManageBilling,
      showTeamChat: access.canUseTeamChat,
    );
  }
}
