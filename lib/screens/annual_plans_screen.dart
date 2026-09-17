import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';

class AnnualPlansScreen extends StatefulWidget {
  const AnnualPlansScreen({super.key});

  @override
  State<AnnualPlansScreen> createState() => _AnnualPlansScreenState();
}

class _AnnualPlansScreenState extends State<AnnualPlansScreen> {
  bool _loading = true;
  final int _year = DateTime.now().year;
  List<Map<String, dynamic>> _plans = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _goals = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(dynamic response, String key) {
    dynamic data = response;
    if (data is Map && data[key] is List) data = data[key];
    if (data is Map && data['data'] is List) data = data['data'];
    if (data is Map && data['data'] is Map && data['data']['data'] is List) {
      data = data['data']['data'];
    }
    return data is List
        ? data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final plansResponse = await ApiClient.instance.get(
        'annual-plans?year=$_year&per_page=100',
        cacheable: false,
      );
      dynamic goalsResponse;
      try {
        goalsResponse = await ApiClient.instance.get(
          'personal-goals?per_page=100',
          cacheable: false,
        );
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _plans = _rows(plansResponse, 'plans');
        _goals = _rows(goalsResponse, 'data');
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _id(dynamic value) => int.tryParse('${value ?? ''}');

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final title = TextEditingController(text: '${existing?['title'] ?? ''}');
    final description = TextEditingController(
      text: '${existing?['description'] ?? ''}',
    );
    int progress = int.tryParse('${existing?['progress_percent'] ?? 0}') ?? 0;
    String period = '${existing?['period'] ?? 'annually'}';
    int? month = _id(existing?['plan_month']);
    int? goalId = _id(existing?['personal_goal_id']);
    DateTime? target = DateTime.tryParse('${existing?['target_date'] ?? ''}');
    DateTime? reminder = DateTime.tryParse(
      '${existing?['reminder_at'] ?? ''}',
    )?.toLocal();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 22,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? 'New Annual Plan' : 'Edit Annual Plan',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: goalId,
                  decoration: const InputDecoration(
                    labelText: 'Linked goal',
                    helperText: 'Optional — choose one of your personal goals.',
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No linked goal'),
                    ),
                    ..._goals.map(
                      (goal) => DropdownMenuItem(
                        value: _id(goal['id']),
                        child: Text(
                          '${goal['title'] ?? goal['name'] ?? 'Goal'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setLocal(() => goalId = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: period,
                  decoration: const InputDecoration(labelText: 'Period'),
                  items: const [
                    DropdownMenuItem(value: 'annually', child: Text('Annual')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) =>
                      setLocal(() => period = value ?? 'annually'),
                ),
                if (period == 'monthly') ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: month,
                    decoration: const InputDecoration(labelText: 'Month *'),
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          DateFormat.MMMM().format(DateTime(2026, index + 1)),
                        ),
                      ),
                    ),
                    onChanged: (value) => setLocal(() => month = value),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 10),
                Text('Progress: $progress%'),
                Slider(
                  value: progress.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '$progress%',
                  onChanged: (value) =>
                      setLocal(() => progress = value.round()),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Target date'),
                  subtitle: Text(
                    target == null
                        ? 'Not set'
                        : DateFormat('d MMM yyyy').format(target!),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: target ?? DateTime(_year, 12, 31),
                      firstDate: DateTime(_year, 1, 1),
                      lastDate: DateTime(_year + 5, 12, 31),
                    );
                    if (picked != null) setLocal(() => target = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reminder'),
                  subtitle: Text(
                    reminder == null
                        ? 'Not set'
                        : DateFormat('d MMM yyyy, h:mm a').format(reminder!),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: reminder ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime(_year + 5, 12, 31),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: reminder == null
                          ? TimeOfDay.now()
                          : TimeOfDay.fromDateTime(reminder!),
                    );
                    if (time == null) return;
                    setLocal(() {
                      reminder = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(existing == null ? 'Save Plan' : 'Update Plan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true) return;
    if (title.text.trim().isEmpty || (period == 'monthly' && month == null)) {
      return;
    }

    final body = <String, dynamic>{
      'personal_goal_id': goalId,
      'title': title.text.trim(),
      'plan_year': _year,
      'period': period,
      'plan_month': period == 'monthly' ? month : null,
      'description': description.text.trim().isEmpty
          ? null
          : description.text.trim(),
      'target_date': target == null
          ? null
          : DateFormat('yyyy-MM-dd').format(target!),
      'reminder_at': reminder?.toIso8601String(),
      'progress_percent': progress,
    };

    try {
      if (existing == null) {
        await ApiClient.instance.post('annual-plans', body);
      } else {
        await ApiClient.instance.put('annual-plans/${existing['id']}', body);
      }
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  // ── Statistics helpers ──
  int get _totalPlans => _plans.length;

  int get _annualCount =>
      _plans.where((p) => (p['period'] ?? '').toString() == 'annually').length;

  int get _monthlyCount =>
      _plans.where((p) => (p['period'] ?? '').toString() == 'monthly').length;

  int get _averageProgress {
    if (_plans.isEmpty) return 0;
    final total = _plans.fold<int>(
      0,
      (sum, p) => sum + (int.tryParse('${p['progress_percent'] ?? 0}') ?? 0),
    );
    return (total / _plans.length).round();
  }

  List<Map<String, dynamic>> get _wellbeingGoals => _goals
      .where((goal) {
        final module = (goal['module'] ?? '').toString().toLowerCase();
        return const <String>{'exercise', 'diet', 'sleep'}.contains(module);
      })
      .toList(growable: false);

  double _wellbeingProgress(String module) {
    final goals = _wellbeingGoals
        .where((g) => (g['module'] ?? '').toString().toLowerCase() == module)
        .toList(growable: false);
    if (goals.isEmpty) return 0;
    return (goals.fold<double>(
              0,
              (sum, g) =>
                  sum + (int.tryParse('${g['progress_percent'] ?? 0}') ?? 0),
            ) /
            goals.length)
        .clamp(0, 100)
        .toDouble();
  }

  double get _overallWellbeingProgress {
    if (_wellbeingGoals.isEmpty) return 0;
    return (_wellbeingGoals.fold<double>(
              0,
              (sum, g) =>
                  sum + (int.tryParse('${g['progress_percent'] ?? 0}') ?? 0),
            ) /
            _wellbeingGoals.length)
        .clamp(0, 100)
        .toDouble();
  }

  // ── Statistics card ──
  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Daily wellbeing statistics card ──
  Widget _wellbeingCard(
    String label,
    double progress,
    IconData icon,
    Color color,
  ) {
    final percent = progress.round();
    return Container(
      width: 132,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$percent%',
            maxLines: 1,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 5,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  // ── Plan card with progress bar ──
  Widget _planCard(BuildContext context, Map<String, dynamic> plan) {
    final progress = int.tryParse('${plan['progress_percent'] ?? 0}') ?? 0;
    final isMonthly = (plan['period'] ?? '').toString() == 'monthly';
    final month = _id(plan['plan_month']);
    final periodLabel = isMonthly
        ? (month != null
              ? DateFormat.MMMM().format(DateTime(2000, month))
              : 'Monthly')
        : 'Annual';
    final target = DateTime.tryParse('${plan['target_date'] ?? ''}');
    final linkedGoalTitle =
        '${plan['personal_goal'] is Map ? plan['personal_goal']!['title'] : ''}'
            .trim();
    final description = '${plan['description'] ?? ''}'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openForm(plan),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${plan['title'] ?? 'Plan'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      periodLabel,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              if (linkedGoalTitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        linkedGoalTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (progress.clamp(0, 100)) / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '$progress%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  const Spacer(),
                  if (target != null) ...[
                    Text(
                      _daysLeftLabel(target),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _daysLeftColor(target),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Target: ${DateFormat('d MMM yyyy').format(target)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _daysLeftLabel(DateTime target) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(target.year, target.month, target.day);
    final days = due.difference(today).inDays;
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return '$days days left';
  }

  Color _daysLeftColor(DateTime target) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(target.year, target.month, target.day);
    final days = due.difference(today).inDays;
    if (days < 0) return const Color(0xFFDC2626);
    if (days <= 7) return const Color(0xFFD97706);
    return const Color(0xFF00897B);
  }

  @override
  Widget build(BuildContext context) {
    final hasPlans = _plans.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text('Annual Plans · $_year'),
        actions: [
          IconButton(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _plans.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  // ── Statistics cards ──
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 800
                        ? 4
                        : 2,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      _statCard(
                        'Total Plans',
                        '$_totalPlans',
                        Icons.task_alt_rounded,
                        const Color(0xFF6366F1),
                      ),
                      _statCard(
                        'Annual',
                        '$_annualCount',
                        Icons.event_available_rounded,
                        const Color(0xFF00897B),
                      ),
                      _statCard(
                        'Monthly',
                        '$_monthlyCount',
                        Icons.date_range_rounded,
                        const Color(0xFF0EA5E9),
                      ),
                      _statCard(
                        'Avg Progress',
                        '$_averageProgress%',
                        Icons.trending_up_rounded,
                        const Color(0xFF059669),
                      ),
                    ],
                  ),
                  // ── Daily wellbeing statistics cards ──
                  if (_wellbeingGoals.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Daily Wellbeing',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 92,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _wellbeingCard(
                            'Exercise',
                            _wellbeingProgress('exercise'),
                            Icons.directions_run_rounded,
                            const Color(0xFF0EA5E9),
                          ),
                          _wellbeingCard(
                            'Diet',
                            _wellbeingProgress('diet'),
                            Icons.restaurant_rounded,
                            const Color(0xFFF59E0B),
                          ),
                          _wellbeingCard(
                            'Sleep',
                            _wellbeingProgress('sleep'),
                            Icons.bedtime_rounded,
                            const Color(0xFF8B5CF6),
                          ),
                          _wellbeingCard(
                            'Overall',
                            _overallWellbeingProgress,
                            Icons.favorite_rounded,
                            const Color(0xFF059669),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Plans',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (!hasPlans)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.rocket_launch_outlined,
                              size: 42,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No plans for $_year yet.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap + to add your first annual plan.',
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
                    ..._plans.map((plan) => _planCard(context, plan)),
                ],
              ),
      ),
    );
  }
}
