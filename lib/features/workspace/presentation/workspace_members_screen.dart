import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../models/workspace_member_management_models.dart';
import '../services/workspace_member_management_service.dart';

class WorkspaceMembersScreen extends StatefulWidget {
  const WorkspaceMembersScreen({super.key});

  @override
  State<WorkspaceMembersScreen> createState() =>
      _WorkspaceMembersScreenState();
}

class _WorkspaceMembersScreenState
    extends State<WorkspaceMembersScreen> {
  final WorkspaceMemberManagementService _service =
      WorkspaceMemberManagementService();

  WorkspaceMemberManagement? _data;
  bool _loading = true;
  bool _actionRunning = false;
  String? _error;

  static const _roles = <String, String>{
    'member': 'Member',
    'viewer': 'Viewer',
    'staff': 'Staff',
    'admin': 'Administrator',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _service.load();

      if (!mounted) return;

      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load organization members.';
      });
    }
  }

  Future<void> _invite() async {
    final data = _data;

    if (data == null) return;

    if (!data.hasSeatAvailable) {
      _showMessage(
        'All member seats on this subscription are currently in use.',
      );
      return;
    }

    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    String role = 'member';
    bool obscurePassword = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Add Member',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Member name',
                          hintText: 'Required for a new account',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'member@example.com',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(
                          labelText: 'Workspace role',
                        ),
                        items: _roles.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => role = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Temporary password',
                          hintText: 'New users only',
                          helperText:
                              'Leave blank for an existing My Digital Diary user.',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(
                                () => obscurePassword = !obscurePassword,
                              );
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${data.remainingSeats} seat(s) available.\n\n'
                          'Existing account: the current password is kept.\n'
                          'New account: enter a name and temporary password '
                          'with at least 8 characters, letters and numbers. '
                          'Share the password separately with the member.',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final email = emailController.text.trim();

                    if (email.isEmpty || !email.contains('@')) {
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add Member'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    await _runAction(
      () => _service.invite(
        name: nameController.text,
        email: emailController.text,
        role: role,
        temporaryPassword: passwordController.text,
      ),
    );
  }

  Future<void> _editMember(
    WorkspaceManagedMember member,
  ) async {
    final emailController = TextEditingController(
      text: member.email,
    );

    String role = _roles.containsKey(
      member.role.toLowerCase(),
    )
        ? member.role.toLowerCase()
        : 'member';

    final pending = member.isPending;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Member'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      readOnly: !pending,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email address',
                        helperText: pending
                            ? 'Pending invitation email can be corrected.'
                            : 'Active member email is managed in their profile.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Workspace role',
                      ),
                      items: _roles.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(
                            () => role = value,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, true),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    await _runAction(
      () => _service.editMember(
        membershipId: member.membershipId,
        email: emailController.text,
        role: role,
      ),
    );
  }

  Future<void> _changeRole(
    WorkspaceManagedMember member,
  ) async {
    String role = _roles.containsKey(member.role.toLowerCase())
        ? member.role.toLowerCase()
        : 'member';

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assign Role'),
        content: StatefulBuilder(
          builder: (context, setDialogState) =>
              DropdownButtonFormField<String>(
            initialValue: role,
            items: _roles.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                setDialogState(() => role = value);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, role),
            child: const Text('Save Role'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    await _runAction(
      () => _service.updateRole(
        member.membershipId,
        selected,
      ),
    );
  }

  Future<void> _remove(
    WorkspaceManagedMember member,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          'Remove ${member.email} from this organization? '
          'Their personal diary information will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (yes == true) {
      await _runAction(
        () => _service.remove(member.membershipId),
      );
    }
  }

  Future<void> _runAction(
    Future<String> Function() action,
  ) async {
    if (_actionRunning) return;

    setState(() => _actionRunning = true);

    try {
      final message = await action();

      if (!mounted) return;

      _showMessage(message);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not complete that member action.');
    } finally {
      if (mounted) {
        setState(() => _actionRunning = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Members',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Add member',
            onPressed:
                _loading || _actionRunning || data == null
                    ? null
                    : _invite,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(
                  message: _error!,
                  onRetry: _load,
                )
              : data == null
                  ? const _ErrorState(
                      message:
                          'Member management is not available for this subscription.',
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
                          _SummaryCard(data: data),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: data.hasSeatAvailable &&
                                    !_actionRunning
                                ? _invite
                                : null,
                            icon: const Icon(
                              Icons.person_add_alt_1_outlined,
                            ),
                            label: Text(
                              data.hasSeatAvailable
                                  ? 'Add Member'
                                  : 'No Seats Available',
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Members & Invitations',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (data.members.isEmpty)
                            const _EmptyMembers()
                          else
                            ...data.members.map(
                              (member) => _MemberTile(
                                member: member,
                                roleLabel: _roles[
                                        member.role.toLowerCase()] ??
                                    member.role,
                                actionRunning: _actionRunning,
                                onEdit: () =>
                                    _editMember(member),
                                onRole: () =>
                                    _changeRole(member),
                                onToggleActive: member.isInactive
                                    ? () => _runAction(
                                          () => _service.activate(
                                            member.membershipId,
                                          ),
                                        )
                                    : member.isActive
                                        ? () => _runAction(
                                              () => _service.suspend(
                                                member.membershipId,
                                              ),
                                            )
                                        : null,
                                onRemove: () => _remove(member),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final WorkspaceMemberManagement data;

  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF99F6E4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.organizationName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.planName,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Number(
                    label: 'Used',
                    value: '${data.seatsUsed}',
                  ),
                ),
                Expanded(
                  child: _Number(
                    label: 'Available',
                    value: '${data.remainingSeats}',
                  ),
                ),
                Expanded(
                  child: _Number(
                    label: 'Limit',
                    value: '${data.seatLimit}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Number extends StatelessWidget {
  final String label;
  final String value;

  const _Number({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final WorkspaceManagedMember member;
  final String roleLabel;
  final bool actionRunning;
  final VoidCallback onEdit;
  final VoidCallback onRole;
  final VoidCallback? onToggleActive;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.member,
    required this.roleLabel,
    required this.actionRunning,
    required this.onEdit,
    required this.onRole,
    required this.onToggleActive,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final pending = member.isPending;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Text(
                member.name.isNotEmpty
                    ? member.name[0].toUpperCase()
                    : '?',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Chip(label: roleLabel),
                      _Chip(
                        label: pending
                            ? 'Invitation Pending'
                            : member.status,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              enabled: !actionRunning,
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'role':
                    onRole();
                    break;
                  case 'toggle':
                    onToggleActive?.call();
                    break;
                  case 'remove':
                    onRemove();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit member'),
                ),
                if (!pending)
                  const PopupMenuItem(
                    value: 'role',
                    child: Text('Assign role'),
                  ),
                if (onToggleActive != null)
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      member.isInactive
                          ? 'Reactivate'
                          : 'Suspend',
                    ),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyMembers extends StatelessWidget {
  const _EmptyMembers();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.group_add_outlined,
            size: 42,
            color: Colors.black26,
          ),
          SizedBox(height: 10),
          Text(
            'No members yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Use Add Member to invite your first member.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;

  const _ErrorState({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
