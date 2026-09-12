import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  String _selectedScope = 'total';

  Map<String, int> _stats = const <String, int>{
    'active': 0,
    'daily': 0,
    'weekly': 0,
    'total': 0,
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
      dynamic response;
      try {
        response = await ApiClient.instance.get(
          'reminders/overview?scope=$_selectedScope',
          cacheable: false,
        );
      } on ApiException {
        // Older API installations may not have the overview route yet.
        // Fall back to the standard reminders endpoint instead of showing
        // "Server Error" for the whole screen.
        response = await ApiClient.instance.get(
          'reminders?scope=$_selectedScope',
          cacheable: false,
        );
      }

      dynamic rawItems = response;
      dynamic rawStats;

      if (response is Map) {
        rawItems = response['data'] ?? response['reminders'] ?? const [];
        rawStats = response['stats'];
      }

      final items = <Map<String, dynamic>>[];
      if (rawItems is List) {
        for (final raw in rawItems) {
          if (raw is Map) {
            items.add(Map<String, dynamic>.from(raw));
          }
        }
      }

      int countStat(String key, int fallback) {
        if (rawStats is Map) {
          return int.tryParse('${rawStats[key] ?? fallback}') ?? fallback;
        }
        return fallback;
      }

      final active = items.where(_isActive).length;
      final daily = items.where((item) => _frequency(item) == 'daily').length;
      final weekly = items.where((item) => _frequency(item) == 'weekly').length;

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _stats = <String, int>{
          'active': countStat('active', active),
          'daily': countStat('daily', daily),
          'weekly': countStat('weekly', weekly),
          'total': countStat('total', items.length),
        };
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Could not load reminders.';
      });
    }
  }

  bool _isActive(Map<String, dynamic> item) {
    final value = item['is_active'];
    return value == true || value == 1 || value == '1';
  }

  String _frequency(Map<String, dynamic> item) {
    return (item['frequency'] ?? 'once').toString().trim().toLowerCase();
  }

  String _sourceLabel(Map<String, dynamic> item) {
    final source = (item['source_type'] ?? '').toString().trim().toLowerCase();
    final module = (item['module'] ?? '').toString().trim().toLowerCase();

    if (source == 'daily_plan_item' ||
        module == 'daily-planner' ||
        module == 'daily_planner') {
      return 'Daily Planner';
    }
    if (source == 'project_task' ||
        module == 'project-tasks' ||
        module == 'project') {
      return 'Project Task';
    }
    if (source == 'debt' || module == 'debts' || module == 'debt') {
      return 'Debt';
    }
    if (module.isNotEmpty && module != 'custom') {
      return module
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');
    }
    return 'Reminder';
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (date == null) {
      return 'No next time';
    }
    return DateFormat('dd MMM yyyy, h:mm a').format(date);
  }

  String _repeatLabel(String frequency) {
    return switch (frequency) {
      'every_n_minutes' => 'Every few minutes',
      'hourly' => 'Hourly',
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      'annually' => 'Annually',
      _ => 'Once',
    };
  }

  Future<void> _selectScope(String scope) async {
    if (_selectedScope == scope && !_loading) {
      return;
    }

    setState(() => _selectedScope = scope);
    await _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text(
          'Delete “${item['title'] ?? 'this reminder'}”?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ApiClient.instance.delete('reminders/$id');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'All reminders',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Reminders created here, in Daily Planner, Project Tasks and other linked modules appear together.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.9,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                  label: 'Active',
                  value: '${_stats['active'] ?? 0}',
                  icon: Icons.notifications_active_outlined,
                  selected: _selectedScope == 'active',
                  onTap: () => _selectScope('active'),
                ),
                _StatCard(
                  label: 'Daily',
                  value: '${_stats['daily'] ?? 0}',
                  icon: Icons.today_outlined,
                  selected: _selectedScope == 'daily',
                  onTap: () => _selectScope('daily'),
                ),
                _StatCard(
                  label: 'Weekly',
                  value: '${_stats['weekly'] ?? 0}',
                  icon: Icons.date_range_outlined,
                  selected: _selectedScope == 'weekly',
                  onTap: () => _selectScope('weekly'),
                ),
                _StatCard(
                  label: 'Total',
                  value: '${_stats['total'] ?? 0}',
                  icon: Icons.list_alt_outlined,
                  selected: _selectedScope == 'total',
                  onTap: () => _selectScope('total'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'Showing',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _selectedScope == 'total'
                      ? 'All reminders'
                      : '${_selectedScope[0].toUpperCase()}${_selectedScope.substring(1)} reminders',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _items.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_error!),
                  subtitle: const Text('Tap to try again.'),
                  onTap: _load,
                ),
              )
            else if (_items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_outlined,
                        size: 38,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No reminders yet.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Set a reminder while creating a Daily Planner or Project Task, or create a standalone reminder.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          _isActive(item)
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                        ),
                      ),
                      title: Text(
                        (item['title'] ?? 'Reminder').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_dateLabel(item['next_run_at'])),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _SmallChip(_sourceLabel(item)),
                                _SmallChip(_repeatLabel(_frequency(item))),
                                _SmallChip(
                                  _isActive(item) ? 'Active' : 'Inactive',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _delete(item);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: selected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? scheme.primary : const Color(0xFFE2E8F0),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? scheme.primary : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected
                            ? scheme.primary
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;

  const _SmallChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}
