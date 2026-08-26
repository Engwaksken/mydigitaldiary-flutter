import 'package:flutter/material.dart';

import '../features/team_chat/presentation/team_chat_conversations_screen.dart';
import '../features/workspace/presentation/workspace_members_screen.dart';
import '../services/organization_access_service.dart';
import '../widgets/managed_subscription_banner.dart';
import 'subscription_screen.dart';

class WorkspaceHubScreen extends StatefulWidget {
  const WorkspaceHubScreen({super.key});

  @override
  State<WorkspaceHubScreen> createState() =>
      _WorkspaceHubScreenState();
}

class _WorkspaceHubScreenState extends State<WorkspaceHubScreen> {
  final OrganizationAccessService _accessService =
      OrganizationAccessService();

  OrganizationAccessContext? _access;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final access = await _accessService.context();

      if (!mounted) return;

      setState(() {
        _access = access;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workspace & Account',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      100,
                    ),
                    children: [
                      if (access != null)
                        ManagedSubscriptionBanner(
                          contextData: access,
                        ),

                      if (access != null &&
                          access.managedByOwner)
                        const SizedBox(height: 16),

                      if (access != null &&
                          access.canUseTeamChat) ...[
                        _MenuCard(
                          icon: Icons.forum_outlined,
                          title: 'Team Chat',
                          subtitle:
                              'Channels, messages, announcements and shared documents.',
                          onTap: () => _open(
                            const TeamChatConversationsScreen(),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (access != null &&
                          access.canManageMembers) ...[
                        _MenuCard(
                          icon: Icons.groups_2_outlined,
                          title: 'Manage Members',
                          subtitle:
                              'Add members, assign roles and manage workspace access.',
                          onTap: () => _open(
                            const WorkspaceMembersScreen(),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (access != null &&
                          access.canManageBilling)
                        _MenuCard(
                          icon: Icons.credit_card_outlined,
                          title: 'Subscription & Billing',
                          subtitle:
                              'Plan, payments, renewal and subscription settings.',
                          onTap: () => _open(
                            const SubscriptionScreen(),
                          ),
                        ),

                      if (access != null &&
                          access.managedByOwner)
                        const _ManagedMemberNotice(),
                    ],
                  ),
                ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        minVerticalPadding: 14,
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ManagedMemberNotice extends StatelessWidget {
  const _ManagedMemberNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.teal,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your workspace owner manages organisation membership and billing. '
              'Your personal diary remains private.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
