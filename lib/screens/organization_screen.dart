import 'package:flutter/material.dart';
import '../models/organization.dart';
import '../services/organization_service.dart';
import '../services/api_client.dart';
import 'subscription_screen.dart';

/// Mobile equivalent of the web app's Organization page — invite,
/// activate, deactivate, replace, and remove team members. Wording
/// adapts the same way the web page does: "Family & Team" language for
/// a family_team plan, "Organization" language for Enterprise.
class OrganizationScreen extends StatefulWidget {
  const OrganizationScreen({super.key});

  @override
  State<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  final _service = OrganizationService();
  OrganizationInfo? _organization;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final org = await _service.show();
      setState(() {
        _organization = org;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showInviteDialog() async {
    final emailController = TextEditingController();
    String role = 'staff';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Invite Someone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(
                      value: 'admin',
                      child: Text('Admin (can also manage members)')),
                ],
                onChanged: (value) =>
                    setDialogState(() => role = value ?? 'staff'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Send Invite')),
          ],
        ),
      ),
    );

    if (result != true || emailController.text.trim().isEmpty) return;

    try {
      final message = await _service.invite(emailController.text.trim(), role);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _activate(OrganizationMemberInfo member) async {
    try {
      await _service.activate(member.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deactivate(OrganizationMemberInfo member) async {
    try {
      await _service.deactivate(member.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _remove(OrganizationMemberInfo member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this person?'),
        content: Text(
            'This frees their member slot. ${member.email} will move to a Free/Individual plan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.removeMember(member.id);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Removed — their member slot is now free.')));
      await _load();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showReplaceDialog(OrganizationMemberInfo member) async {
    final emailController = TextEditingController();
    String role = 'staff';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Replace This Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Removes ${member.email} and immediately invites someone new to take their place.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                  controller: emailController,
                  decoration:
                      const InputDecoration(labelText: "New person's email"),
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) =>
                    setDialogState(() => role = value ?? 'staff'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Replace')),
          ],
        ),
      ),
    );

    if (result != true || emailController.text.trim().isEmpty) return;

    try {
      final message =
          await _service.replace(member.id, emailController.text.trim(), role);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _organization?.isFamilyTeam == true ? 'Family & Team' : 'Organization';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _organization == null
              ? _buildNoOrganizationState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_organization!.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(_organization!.planName ?? '—',
                                  style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text(
                                  '${_organization!.seatsUsed} / ${_organization!.seatLimit} members used'),
                              LinearProgressIndicator(
                                value: _organization!.seatLimit > 0
                                    ? _organization!.seatsUsed /
                                        _organization!.seatLimit
                                    : 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _organization!.remainingSeats > 0
                            ? _showInviteDialog
                            : null,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Invite Someone'),
                      ),
                      if (_organization!.remainingSeats == 0)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                              'No member slots available — remove someone or upgrade your plan.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange)),
                        ),
                      const SizedBox(height: 16),
                      Text('Members',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_organization!.members.isEmpty)
                        const Text(
                            'No team members yet — invite your first one above.'),
                      ..._organization!.members.map(_buildMemberTile),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNoOrganizationState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              "You don't have any team members to manage yet. Upgrade to Family & Small Team or Enterprise to invite and manage members.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SubscriptionScreen())),
              child: const Text('View Plans'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(OrganizationMemberInfo member) {
    final statusColor = switch (member.status) {
      'active' => Colors.green,
      'invited' => Colors.orange,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(member.email),
        subtitle: Row(
          children: [
            Text(member.role, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Text(member.status,
                style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'activate':
                _activate(member);
                break;
              case 'deactivate':
                _deactivate(member);
                break;
              case 'replace':
                _showReplaceDialog(member);
                break;
              case 'remove':
                _remove(member);
                break;
            }
          },
          itemBuilder: (context) => [
            if (member.status == 'inactive')
              const PopupMenuItem(value: 'activate', child: Text('Reactivate')),
            if (member.status == 'active')
              const PopupMenuItem(
                  value: 'deactivate', child: Text('Deactivate')),
            const PopupMenuItem(value: 'replace', child: Text('Replace')),
            const PopupMenuItem(value: 'remove', child: Text('Remove')),
          ],
        ),
      ),
    );
  }
}
