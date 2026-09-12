import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../models/workspace_models.dart';
import '../services/workspace_service.dart';
import '../widgets/workspace_file_card.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final WorkspaceService _service = WorkspaceService();

  WorkspaceOverview? _workspace;
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;

  static const _tabs = <String>[
    'Overview',
    'Members',
    'Shared',
    'Files',
    'Activity',
  ];

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
      final workspace = await _service.overview();

      if (!mounted) return;

      setState(() {
        _workspace = workspace;
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
        _error = 'Could not load your shared workspace.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = _workspace;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Workspace'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(
                  message: _error!,
                  onRetry: _load,
                )
              : workspace == null || !workspace.enabled
                  ? const _NoWorkspaceState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        children: [
                          _WorkspaceHero(workspace: workspace),
                          const SizedBox(height: 12),
                          _TabStrip(
                            tabs: _tabs,
                            selectedIndex: _tabIndex,
                            onChanged: (index) {
                              setState(() => _tabIndex = index);
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildSelectedTab(workspace),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSelectedTab(WorkspaceOverview workspace) {
    switch (_tabIndex) {
      case 1:
        return _MembersSection(workspace: workspace);
      case 2:
        return _SharedSection(items: workspace.sharedItems);
      case 3:
        return _FilesSection(
          files: workspace.files,
          onDownload: _downloadFile,
        );
      case 4:
        return _ActivitySection(activity: workspace.activity);
      default:
        return _OverviewSection(workspace: workspace);
    }
  }

  Future<void> _downloadFile(WorkspaceFile file) async {
    /*
     * The Laravel workspace endpoint is authenticated. This screen therefore
     * does not construct a public URL or put a bearer token in the browser
     * query string.
     *
     * Wire this call to the project's existing authenticated file-download
     * helper. If ApiClient already exposes downloadFile/downloadBytes, replace
     * this message with that helper and save/open the returned bytes.
     */
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Download ${file.name} using authenticated API path: '
          '${_service.fileDownloadPath(file.id)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  final WorkspaceOverview workspace;

  const _WorkspaceHero({required this.workspace});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF0FDFA),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.groups_2_outlined,
                color: Color(0xFF00897B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workspace.organizationName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${workspace.membersCount} member'
                    '${workspace.membersCount == 1 ? '' : 's'} • '
                    '${workspace.role}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Your personal diary stays private unless you choose '
                    'to share an item with this workspace.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TabStrip({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 39,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;

          return ChoiceChip(
            label: Text(
              tabs[index],
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
            selected: selected,
            onSelected: (_) => onChanged(index),
          );
        },
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final WorkspaceOverview workspace;

  const _OverviewSection({required this.workspace});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.people_outline,
                label: 'Members',
                value: '${workspace.membersCount}',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MetricCard(
                icon: Icons.share_outlined,
                label: 'Shared',
                value: '${workspace.sharedItems.length}',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MetricCard(
                icon: Icons.folder_outlined,
                label: 'Files',
                value: '${workspace.files.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: Color(0xFF00897B),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    workspace.canManageMembers
                        ? 'You can manage this workspace. Member invitation '
                            'and seat controls remain governed by the same '
                            'Laravel organisation used on the web.'
                        : 'You can view items deliberately shared with your '
                            'workspace. Private personal items stay private.',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF00897B)),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  final WorkspaceOverview workspace;

  const _MembersSection({required this.workspace});

  @override
  Widget build(BuildContext context) {
    if (workspace.members.isEmpty) {
      return const _EmptyCard(
        icon: Icons.people_outline,
        title: 'No members yet',
        message: 'Invited and active members will appear here.',
      );
    }

    return Column(
      children: workspace.members.map((member) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  member.name.trim().isEmpty
                      ? '?'
                      : member.name.trim()[0].toUpperCase(),
                ),
              ),
              title: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                member.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: Text(
                  member.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00897B),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _SharedSection extends StatelessWidget {
  final List<WorkspaceSharedItem> items;

  const _SharedSection({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCard(
        icon: Icons.share_outlined,
        title: 'Nothing shared yet',
        message:
            'Only items deliberately shared with the team will appear here.',
      );
    }

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.link_outlined),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  item.itemType,
                  if ((item.sharedByName ?? '').isNotEmpty)
                    'by ${item.sharedByName}',
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                item.permission,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _FilesSection extends StatelessWidget {
  final List<WorkspaceFile> files;
  final ValueChanged<WorkspaceFile> onDownload;

  const _FilesSection({
    required this.files,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const _EmptyCard(
        icon: Icons.folder_open_outlined,
        title: 'No team files yet',
        message: 'Files shared with this workspace will appear here.',
      );
    }

    return Column(
      children: files.map((file) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: WorkspaceFileCard(
            file: file,
            onDownload: () => onDownload(file),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final List<WorkspaceActivity> activity;

  const _ActivitySection({required this.activity});

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return const _EmptyCard(
        icon: Icons.history_outlined,
        title: 'No activity yet',
        message: 'Workspace activity will appear here.',
      );
    }

    return Column(
      children: activity.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.history_outlined),
              title: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                entry.actorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _NoWorkspaceState extends StatelessWidget {
  const _NoWorkspaceState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 60),
        Icon(
          Icons.groups_2_outlined,
          size: 58,
          color: Colors.black26,
        ),
        SizedBox(height: 16),
        Text(
          'No shared workspace',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 7),
        Text(
          'Family / Small Team and Enterprise subscriptions can use a '
          'shared workspace. Your personal diary remains private.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 34, color: Colors.black26),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 70),
        const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.black26),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 14),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
