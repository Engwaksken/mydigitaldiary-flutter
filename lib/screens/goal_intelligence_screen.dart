import 'package:flutter/material.dart';

import '../config/module_configs.dart';
import '../services/api_client.dart';
import 'dynamic_crud_screen.dart';

class GoalIntelligenceScreen extends StatefulWidget {
  const GoalIntelligenceScreen({super.key});

  @override
  State<GoalIntelligenceScreen> createState() =>
      _GoalIntelligenceScreenState();
}

class _GoalIntelligenceScreenState extends State<GoalIntelligenceScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _actions = <Map<String, dynamic>>[];

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
      final response = await ApiClient.instance.get(
        'goal-intelligence',
        cacheable: false,
      );

      dynamic data = response;
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }

      dynamic rawActions;
      if (data is Map) {
        rawActions = data['next_actions'] ??
            data['actions'] ??
            data['recommendations'];
      }

      final actions = <Map<String, dynamic>>[];
      if (rawActions is List) {
        for (final raw in rawActions) {
          if (raw is Map) {
            actions.add(Map<String, dynamic>.from(raw));
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _actions = actions;
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
        _error = 'Could not load goal next actions.';
      });
    }
  }

  void _openGoals() {
    final config = moduleConfigByEndpoint('personal-goals');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DynamicCrudScreen(config: config),
      ),
    );
  }

  void _openAction(Map<String, dynamic> action) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final title =
            (action['title'] ?? action['name'] ?? 'Next action').toString();
        final message = (action['message'] ??
                action['description'] ??
                'Review this goal and choose the next useful step.')
            .toString();
        final state =
            (action['state'] ?? action['status'] ?? '').toString();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message),
                if (state.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Status: ${state.replaceAll('_', ' ')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openGoals();
                  },
                  icon: const Icon(Icons.track_changes_outlined),
                  label: const Text('Open Goals'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals · Next Actions'),
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
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next best actions',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Open an action to see the recommendation, then continue in Goals.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openGoals,
                  child: const Text('All goals'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_error!),
                  subtitle: const Text('Tap to retry.'),
                  onTap: _load,
                ),
              )
            else if (_actions.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('No urgent next actions'),
                  subtitle: const Text(
                    'Open Goals to review your progress and choose what to work on next.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openGoals,
                ),
              )
            else
              ..._actions.map(
                (action) {
                  final title =
                      (action['title'] ?? action['name'] ?? 'Next action')
                          .toString();
                  final message = (action['message'] ??
                          action['description'] ??
                          'Continue making progress on this goal.')
                      .toString();
                  final state =
                      (action['state'] ?? action['status'] ?? '')
                          .toString()
                          .toLowerCase();

                  final warning =
                      state == 'overdue' || state == 'at_risk';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          warning
                              ? Icons.warning_amber_rounded
                              : Icons.trending_up_rounded,
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openAction(action),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
