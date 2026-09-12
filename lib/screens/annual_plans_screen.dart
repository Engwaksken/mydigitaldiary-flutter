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
  int _year = DateTime.now().year;
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
        ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
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
    final description =
        TextEditingController(text: '${existing?['description'] ?? ''}');
    int progress = int.tryParse('${existing?['progress_percent'] ?? 0}') ?? 0;
    String period = '${existing?['period'] ?? 'annually'}';
    int? month = _id(existing?['plan_month']);
    int? goalId = _id(existing?['personal_goal_id']);
    DateTime? target =
        DateTime.tryParse('${existing?['target_date'] ?? ''}');
    DateTime? reminder =
        DateTime.tryParse('${existing?['reminder_at'] ?? ''}')?.toLocal();

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
                    DropdownMenuItem(
                      value: 'annually',
                      child: Text('Annual'),
                    ),
                    DropdownMenuItem(
                      value: 'monthly',
                      child: Text('Monthly'),
                    ),
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
                          DateFormat.MMMM().format(
                            DateTime(2026, index + 1),
                          ),
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
                  decoration:
                      const InputDecoration(labelText: 'Description'),
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
      'description':
          description.text.trim().isEmpty ? null : description.text.trim(),
      'target_date':
          target == null ? null : DateFormat('yyyy-MM-dd').format(target!),
      'reminder_at': reminder?.toIso8601String(),
      'progress_percent': progress,
    };

    try {
      if (existing == null) {
        await ApiClient.instance.post('annual-plans', body);
      } else {
        await ApiClient.instance.put(
          'annual-plans/${existing['id']}',
          body,
        );
      }
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ? ListView(children: const [
                SizedBox(height: 220),
                Center(child: CircularProgressIndicator()),
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _plans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final plan = _plans[index];
                  final progress =
                      int.tryParse('${plan['progress_percent'] ?? 0}') ?? 0;
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${plan['title'] ?? 'Plan'}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${plan['period'] == 'monthly' ? 'Monthly' : 'Annual'} · $progress%',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _openForm(plan),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
