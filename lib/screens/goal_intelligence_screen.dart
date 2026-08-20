import 'package:flutter/material.dart';
import '../services/api_client.dart';

class GoalIntelligenceScreen extends StatefulWidget {
  const GoalIntelligenceScreen({super.key});

  @override
  State<GoalIntelligenceScreen> createState() => _GoalIntelligenceScreenState();
}

class _GoalIntelligenceScreenState extends State<GoalIntelligenceScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _actions = [];
  List<Map<String, dynamic>> _goals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });

    try {
      dynamic response;
      try {
        response = await ApiClient.instance
            .get('dashboard', cacheable: false)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        response = await ApiClient.instance
            .get('dashboard', cacheable: true)
            .timeout(const Duration(seconds: 4));
      }

      dynamic root = response;
      if (root is Map && root['data'] is Map) root = root['data'];

      Map<String, dynamic> intelligence = {};
      if (root is Map) {
        final map = Map<String, dynamic>.from(root);
        intelligence = map['goal_intelligence'] is Map
            ? Map<String, dynamic>.from(map['goal_intelligence'] as Map)
            : map;
      }

      final actions = _asList(
        intelligence['next_actions'] ??
            intelligence['recommended_actions'] ??
            intelligence['actions'],
      );
      final goals = _asList(
        intelligence['active_goals'] ??
            intelligence['goals'] ??
            intelligence['items'],
      );

      if (!mounted) return;
      setState(() {
        _actions = actions;
        _goals = goals;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load goals and next actions.';
      });
    }
  }

  List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw is Map && raw['data'] is List) raw = raw['data'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _text(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  double _progress(Map<String, dynamic> item) {
    dynamic raw = item['progress_percent'] ??
        item['completion_percent'] ??
        item['progress'] ??
        item['percentage'] ??
        0;

    if (raw is Map) raw = raw['percent'] ?? raw['value'] ?? 0;

    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw.toString().replaceAll('%', '')) ?? 0;

    return value.clamp(0, 100);
  }

  String _state(Map<String, dynamic> item) {
    final state = _text(item, const ['state', 'status', 'health']);
    return state.isEmpty ? 'needs attention' : state;
  }

  bool _urgent(String state) {
    final value = state.toLowerCase();
    return value.contains('overdue') ||
        value.contains('risk') ||
        value.contains('late');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goals & Next Actions')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_loading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 18),
            ],
            if (_error != null) ...[
              _InfoCard(
                icon: Icons.warning_amber_rounded,
                title: 'Unable to refresh goals',
                message: _error!,
                onTap: _load,
              ),
              const SizedBox(height: 24),
            ],

            Text(
              'Recommended next actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),

            if (!_loading && _actions.isEmpty)
              const _InfoCard(
                icon: Icons.check_circle_outline,
                title: 'No urgent next actions',
                message: 'Recommended goal actions will appear here.',
              )
            else
              ..._actions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ActionCard(
                    title: _text(item, const ['title', 'name', 'goal_title']),
                    message: _text(item, const [
                      'message',
                      'description',
                      'next_action',
                      'recommendation'
                    ]),
                    urgent: _urgent(_state(item)),
                  ),
                ),
              ),

            const SizedBox(height: 14),
            Text(
              'Active goals',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),

            if (!_loading && _goals.isEmpty)
              const _InfoCard(
                icon: Icons.track_changes_outlined,
                title: 'No active goals',
                message: 'Create a goal to begin tracking progress.',
              )
            else
              ..._goals.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _GoalCard(
                    type: _text(item, const [
                      'type',
                      'source',
                      'category',
                      'goal_type'
                    ]),
                    title: _text(item, const ['title', 'name', 'goal_title']),
                    state: _state(item),
                    progress: _progress(item),
                    due: _text(item, const [
                      'due_date',
                      'deadline',
                      'target_date'
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String message;
  final bool urgent;

  const _ActionCard({
    required this.title,
    required this.message,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        urgent ? const Color(0xFFD97706) : const Color(0xFF0F766E);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            urgent
                ? Icons.warning_amber_rounded
                : Icons.arrow_circle_up_outlined,
            size: 31,
            color: accent,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Next action' : title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String type;
  final String title;
  final String state;
  final double progress;
  final String due;

  const _GoalCard({
    required this.type,
    required this.title,
    required this.state,
    required this.progress,
    required this.due,
  });

  @override
  Widget build(BuildContext context) {
    final stateLower = state.toLowerCase();
    final stateColor = stateLower.contains('overdue')
        ? const Color(0xFFD97706)
        : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (type.isNotEmpty)
                      Text(
                        type,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      title.isEmpty ? 'Goal' : title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                state,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: stateColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2F3EF),
              valueColor: const AlwaysStoppedAnimation(
                Color(0xFF0F9D8A),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${progress.round()}% complete'
            '${due.isNotEmpty ? ' • Due $due' : ''}',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
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
