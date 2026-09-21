import 'package:flutter/material.dart';
import '../services/api_client.dart';

class GoalProgressScreen extends StatefulWidget {
  final int goalId;
  final String? initialTitle;
  const GoalProgressScreen(
      {super.key, required this.goalId, this.initialTitle});

  @override
  State<GoalProgressScreen> createState() => _GoalProgressScreenState();
}

class _GoalProgressScreenState extends State<GoalProgressScreen> {
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _data = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await ApiClient.instance
          .get('personal-goals/${widget.goalId}/progress', cacheable: true);
      final wrapped =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final body = wrapped['data'];
      if (!mounted) return;
      setState(() {
        _data =
            body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  Future<void> _addMilestone() async {
    final title = TextEditingController();
    final weight = TextEditingController();
    DateTime? targetDate;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add milestone'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Milestone',
                      hintText: 'e.g. Complete first module')),
              const SizedBox(height: 10),
              TextField(
                  controller: weight,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Weight % (optional)')),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Target date'),
                subtitle: Text(targetDate == null
                    ? 'Optional'
                    : '${targetDate!.day}/${targetDate!.month}/${targetDate!.year}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                      context: ctx,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 3650)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: targetDate ?? DateTime.now());
                  if (picked != null) setDialogState(() => targetDate = picked);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (accepted != true || title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiClient.instance
          .post('personal-goals/${widget.goalId}/milestones', {
        'title': title.text.trim(),
        if (weight.text.trim().isNotEmpty)
          'weight': int.tryParse(weight.text.trim()),
        if (targetDate != null)
          'target_date':
              '${targetDate!.year.toString().padLeft(4, '0')}-${targetDate!.month.toString().padLeft(2, '0')}-${targetDate!.day.toString().padLeft(2, '0')}',
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> milestone) async {
    final id = (milestone['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await ApiClient.instance.patch(
          'personal-goals/${widget.goalId}/milestones/$id/toggle', const {});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> milestone) async {
    final id = (milestone['id'] as num?)?.toInt();
    if (id == null) return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Delete milestone?'),
              content: Text(
                  'Remove “${milestone['title'] ?? 'this milestone'}” from the goal?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'))
              ],
            ));
    if (ok != true) return;
    try {
      await ApiClient.instance
          .delete('personal-goals/${widget.goalId}/milestones/$id');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _rescheduleMilestone(
      Map<String, dynamic> milestone, String suggested) async {
    final id = (milestone['id'] as num?)?.toInt();
    if (id == null) return;
    final initial = DateTime.tryParse(suggested) ??
        DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (picked == null) return;
    final date =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    try {
      await ApiClient.instance.patch(
          'personal-goals/${widget.goalId}/milestones/$id/reschedule',
          {'target_date': date});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _weeklyCheckin(Map<String, dynamic> current) async {
    int confidence = (current['confidence'] as num?)?.toInt() ?? 3;
    final action = TextEditingController(
        text: current['planned_action']?.toString() ?? '');
    final note = TextEditingController(text: current['note']?.toString() ?? '');
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setStateDialog) => AlertDialog(
                  title: const Text('Weekly goal check-in'),
                  content: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text(
                            'How confident are you that you can move this goal this week?',
                            style: TextStyle(fontSize: 13)),
                        Slider(
                            value: confidence.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: '$confidence',
                            onChanged: (v) =>
                                setStateDialog(() => confidence = v.round())),
                        TextField(
                            controller: action,
                            decoration: const InputDecoration(
                                labelText: 'One action I will complete')),
                        const SizedBox(height: 8),
                        TextField(
                            controller: note,
                            maxLines: 2,
                            decoration: const InputDecoration(
                                labelText: 'Optional note')),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Save'))
                  ],
                )));
    if (ok != true || action.text.trim().isEmpty) return;
    try {
      await ApiClient.instance
          .post('personal-goals/${widget.goalId}/check-in', {
        'confidence': confidence,
        'planned_action': action.text.trim(),
        if (note.text.trim().isNotEmpty) 'note': note.text.trim()
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = _data['goal'] is Map
        ? Map<String, dynamic>.from(_data['goal'] as Map)
        : <String, dynamic>{};
    final snapshot = _data['snapshot'] is Map
        ? Map<String, dynamic>.from(_data['snapshot'] as Map)
        : <String, dynamic>{};
    final week = _data['week'] is Map
        ? Map<String, dynamic>.from(_data['week'] as Map)
        : <String, dynamic>{};
    final accountability = _data['accountability'] is Map
        ? Map<String, dynamic>.from(_data['accountability'] as Map)
        : <String, dynamic>{};
    final checkin = accountability['checkin'] is Map
        ? Map<String, dynamic>.from(accountability['checkin'] as Map)
        : <String, dynamic>{};
    final overdueMilestones = _maps(accountability['overdue_milestones']);
    final components = snapshot['components'] is Map
        ? Map<String, dynamic>.from(snapshot['components'] as Map)
        : <String, dynamic>{};
    final milestones = _maps(_data['milestones']);
    final movement = _maps(week['items']);
    final progress = (snapshot['progress'] as num?)?.toDouble() ??
        (goal['progress_percent'] as num?)?.toDouble() ??
        0;

    return Scaffold(
      appBar: AppBar(
          title: Text(goal['title']?.toString() ??
              widget.initialTitle ??
              'Goal Progress')),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _addMilestone,
              icon: const Icon(Icons.add),
              label: const Text('Milestone')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                children: [
                  Text(
                      '${(goal['module'] ?? 'personal').toString().replaceAll('_', ' ')} goal'
                          .toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 4),
                  Text(goal['title']?.toString() ?? '',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  if ((goal['description']?.toString() ?? '')
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(goal['description'].toString(),
                        style: const TextStyle(color: Colors.black54))
                  ],
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Automatic progress',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            Row(children: [
                              Text('${progress.round()}%',
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800)),
                              const Spacer(),
                              const Icon(Icons.trending_up_rounded, size: 28),
                            ]),
                            const SizedBox(height: 9),
                            LinearProgressIndicator(
                                value: (progress / 100).clamp(0, 1),
                                minHeight: 9,
                                borderRadius: BorderRadius.circular(10)),
                            if (components.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: components.entries
                                      .map((e) => Chip(
                                          label: Text(
                                              '${_componentLabel(e.key)} ${e.value}%')))
                                      .toList()),
                            ],
                          ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('What moved this goal this week?',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 3),
                            Text(
                                '${week['movement_count'] ?? 0} meaningful action${week['movement_count'] == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text(week['message']?.toString() ?? '',
                                style: const TextStyle(
                                    fontSize: 13, height: 1.35)),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Expanded(
                                      child: Text('Goal accountability',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54))),
                                  _StatusPill(
                                      status: accountability['status']
                                              ?.toString() ??
                                          'on_track',
                                      label: accountability['status_label']
                                              ?.toString() ??
                                          'On Track')
                                ]),
                                const SizedBox(height: 6),
                                Text(
                                    accountability['message']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 13, height: 1.35)),
                                if (accountability['expected_progress'] !=
                                    null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                      'Actual ${accountability['progress'] ?? 0}% · Expected ${accountability['expected_progress']}%',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700))
                                ],
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                    onPressed: () => _weeklyCheckin(checkin),
                                    icon: const Icon(Icons.fact_check_outlined,
                                        size: 18),
                                    label: Text(checkin.isEmpty
                                        ? 'Weekly check-in'
                                        : 'Update weekly check-in')),
                              ]))),
                  if (overdueMilestones.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                        color: const Color(0xFFFFF8E7),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                  padding: EdgeInsets.fromLTRB(14, 14, 14, 6),
                                  child: Text('Missed milestones',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800))),
                              for (var i = 0;
                                  i < overdueMilestones.length;
                                  i++) ...[
                                ListTile(
                                    dense: true,
                                    title: Text(overdueMilestones[i]['title']
                                            ?.toString() ??
                                        ''),
                                    subtitle: Text(
                                        '${overdueMilestones[i]['days_overdue'] ?? 0} days overdue'),
                                    trailing: TextButton(
                                        onPressed: () => _rescheduleMilestone(
                                            overdueMilestones[i],
                                            overdueMilestones[i]
                                                        ['suggested_date']
                                                    ?.toString() ??
                                                ''),
                                        child: const Text('Reschedule'))),
                                if (i != overdueMilestones.length - 1)
                                  const Divider(height: 1),
                              ]
                            ])),
                  ],
                  const SizedBox(height: 18),
                  Row(children: [
                    const Expanded(
                        child: Text('Milestones',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800))),
                    Text(
                        '${snapshot['milestones_completed'] ?? 0}/${snapshot['milestones_total'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w700))
                  ]),
                  const SizedBox(height: 7),
                  if (milestones.isEmpty)
                    const Card(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'No milestones yet. Add a checkpoint that makes this goal easier to finish.')))
                  else
                    Card(
                      child: Column(children: [
                        for (var i = 0; i < milestones.length; i++) ...[
                          _MilestoneTile(
                              milestone: milestones[i],
                              onToggle: () => _toggle(milestones[i]),
                              onDelete: () => _delete(milestones[i])),
                          if (i != milestones.length - 1)
                            const Divider(height: 1),
                        ],
                      ]),
                    ),
                  const SizedBox(height: 18),
                  const Text('This week’s movement',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  if (movement.isEmpty)
                    const Card(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'Complete a linked task or milestone and it will appear here.')))
                  else
                    Card(
                        child: Column(children: [
                      for (var i = 0; i < movement.length; i++) ...[
                        ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_upward_rounded),
                            title: Text(movement[i]['title']?.toString() ?? ''),
                            subtitle: Text(
                                movement[i]['type']?.toString() ?? 'Activity')),
                        if (i != movement.length - 1) const Divider(height: 1),
                      ]
                    ]))
                ],
              ),
      ),
    );
  }

  String _componentLabel(String key) => switch (key) {
        'value' => 'Target',
        'milestones' => 'Milestones',
        'tasks' => 'Tasks',
        'plans' => 'Plans',
        _ => key,
      };
}

class _MilestoneTile extends StatelessWidget {
  final Map<String, dynamic> milestone;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _MilestoneTile(
      {required this.milestone,
      required this.onToggle,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final done = milestone['status'] == 'completed';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      leading: IconButton(
          onPressed: onToggle,
          icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? Colors.green : Colors.grey)),
      title: Text(milestone['title']?.toString() ?? '',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: done ? TextDecoration.lineThrough : null,
              color: done ? Colors.black45 : null)),
      subtitle: milestone['target_date'] != null
          ? Text('Target ${milestone['target_date']}')
          : null,
      trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 20)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final String label;
  const _StatusPill({required this.status, required this.label});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ahead' => Colors.green,
      'at_risk' => Colors.orange,
      'overdue' => Colors.red,
      'completed' => Colors.blue,
      _ => Colors.deepPurple
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color)));
  }
}
