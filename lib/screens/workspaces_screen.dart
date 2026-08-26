import 'package:flutter/material.dart';

import '../services/workspace_service.dart';

class WorkspacesScreen extends StatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  State<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends State<WorkspacesScreen> {
  final _service = const WorkspaceService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

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
      final items = await _service.list();

      if (!mounted) return;

      setState(() {
        _items = items;
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

  static String label(dynamic value) {
    final text = (value ?? '').toString().replaceAll('_', ' ').trim();
    if (text.isEmpty) return '';

    return text
        .split(' ')
        .map(
          (part) =>
              '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Workspaces'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFF047857),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your Personal Space remains private. Workspace owners and administrators only see records deliberately shared to the workspace.',
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 42),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 36,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Could not load your workspaces.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 42,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No shared workspace yet.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Family/Small Team workspaces can be created from the web workspace area. Enterprise requires approved onboarding.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._items.map((item) {
                final workspace = item['workspace'] is Map
                    ? Map<String, dynamic>.from(item['workspace'])
                    : <String, dynamic>{};

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          workspace['type'] == 'enterprise'
                              ? Icons.apartment_rounded
                              : Icons.groups_rounded,
                        ),
                      ),
                      title: Text(
                        (workspace['name'] ?? 'Workspace').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${label(workspace['type'])} · ${label(item['role'])}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        final id = int.tryParse(
                          (workspace['id'] ?? '').toString(),
                        );

                        if (id == null) return;

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorkspaceDetailsScreen(
                              workspaceId: id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class WorkspaceDetailsScreen extends StatefulWidget {
  const WorkspaceDetailsScreen({
    super.key,
    required this.workspaceId,
  });

  final int workspaceId;

  @override
  State<WorkspaceDetailsScreen> createState() =>
      _WorkspaceDetailsScreenState();
}

class _WorkspaceDetailsScreenState extends State<WorkspaceDetailsScreen> {
  final _service = const WorkspaceService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _workspace = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.show(widget.workspaceId);

      if (!mounted) return;

      setState(() {
        _workspace = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _workspace['members'] is List
        ? _workspace['members'] as List
        : const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (_workspace['name'] ?? 'Workspace').toString(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Personal Space is private by default. Only records deliberately shared into this workspace are collaborative.',
                        style: TextStyle(
                          color: Color(0xFF1E40AF),
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your role: ${WorkspacesScreenStateLabel.value(_workspace['my_role'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Members (${members.length})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...members.whereType<Map>().map((raw) {
                      final member = Map<String, dynamic>.from(raw);
                      final user = member['user'] is Map
                          ? Map<String, dynamic>.from(member['user'])
                          : <String, dynamic>{};

                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline_rounded),
                          ),
                          title: Text(
                            (user['name'] ?? 'Member').toString(),
                          ),
                          subtitle: Text(
                            '${user['email'] ?? ''} · ${WorkspacesScreenStateLabel.value(member['role'])}',
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}

class WorkspacesScreenStateLabel {
  static String value(dynamic input) {
    final text = (input ?? '').toString().replaceAll('_', ' ').trim();
    if (text.isEmpty) return '';

    return text
        .split(' ')
        .map(
          (part) =>
              '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}
