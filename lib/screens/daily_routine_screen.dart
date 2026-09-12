import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/personal_management_service.dart';

enum DailyRoutineMode { start, end }

class DailyRoutineScreen extends StatefulWidget {
  final DailyRoutineMode mode;
  const DailyRoutineScreen.start({super.key}) : mode = DailyRoutineMode.start;
  const DailyRoutineScreen.end({super.key}) : mode = DailyRoutineMode.end;

  @override
  State<DailyRoutineScreen> createState() => _DailyRoutineScreenState();
}

class _DailyRoutineScreenState extends State<DailyRoutineScreen> {
  final _service = const PersonalManagementService();
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;
  final _reflection = TextEditingController();
  final _gratitude = TextEditingController();
  final _tomorrowFocus = TextEditingController();
  int? _mood;
  bool _saving = false;

  bool get _start => widget.mode == DailyRoutineMode.start;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _reflection.dispose(); _gratitude.dispose(); _tomorrowFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.routine(_start ? 'start' : 'end');
      if (!mounted) return;
      setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load the daily routine.'; });
    }
  }

  List<Map<String, dynamic>> _rows(String key) {
    final raw = _data[key];
    return raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false)
        : <Map<String, dynamic>>[];
  }

  Widget _section(String title, IconData icon, List<Map<String, dynamic>> rows, String Function(Map<String, dynamic>) label, {String empty = 'Nothing due here.'}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(empty, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))
          else
            ...rows.take(6).map(
              (row) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label(row),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final payload = <String, dynamic>{
          'mood': _mood,
          'reflection': _reflection.text.trim().isEmpty ? null : _reflection.text.trim(),
          'gratitude': _gratitude.text.trim().isEmpty ? null : _gratitude.text.trim(),
          'tomorrow_focus': _start || _tomorrowFocus.text.trim().isEmpty ? null : _tomorrowFocus.text.trim(),
          'meta': {'routine_version': 2},
        };

    try {
      try {
        await _service.saveCheckin(
          _start ? 'start-day' : 'close-day',
          payload,
        );
      } on ApiException {
        // Compatibility fallback for installations exposing daily-routine
        // write endpoints directly.
        await ApiClient.instance.post(
          _start ? 'daily-routine/start-day' : 'daily-routine/close-day',
          payload,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_start ? 'Your day is ready to begin.' : 'Your day has been closed.')));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorities = _rows(_start ? 'priorities' : 'completed_tasks');
    final secondary = _rows(_start ? 'meetings' : 'incomplete_tasks');
    final relationships = _rows('relationships');
    final reminders = _rows('reminders');
    final tasksDue = _rows('tasks_due');

    return Scaffold(
      appBar: AppBar(title: Text(_start ? 'Start Day' : 'End Day'), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            Text(
              _start
                  ? 'Prepare intentionally: confirm priorities, commitments, wellbeing and people who need attention.'
                  : 'Close the loop: recognise progress, reschedule what matters and record what you learned.',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            if (_loading && _data.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 120), child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _data.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 80), child: Text(_error!, textAlign: TextAlign.center))
            else ...[
              _section(_start ? 'Today’s priorities' : 'Completed tasks', _start ? Icons.bolt_rounded : Icons.check_circle_outline_rounded, priorities,
                  (r) => (r['title'] ?? r['name'] ?? 'Item').toString(),
                  empty: _start ? 'No priorities yet. Open Daily Planner and choose what matters today.' : 'No completed tasks recorded yet.'),
              _section(_start ? 'Calendar / meetings' : 'Incomplete tasks to review', _start ? Icons.calendar_month_outlined : Icons.redo_rounded, secondary,
                  (r) => (r['title'] ?? r['name'] ?? r['meeting_title'] ?? 'Item').toString(),
                  empty: _start ? 'No meetings scheduled today.' : 'Nothing needs carrying forward.'),
              if (_start) ...[
                _section('Tasks due today', Icons.task_alt_outlined, tasksDue, (r) => (r['title'] ?? 'Task').toString()),
                _section('Upcoming reminders', Icons.notifications_outlined, reminders, (r) => (r['title'] ?? r['message'] ?? 'Reminder').toString()),
                _section('Important people to follow up', Icons.people_outline_rounded, relationships, (r) => (r['name'] ?? 'Person').toString(), empty: 'No relationship check-ins due soon.'),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(child: _moneyMetric('Income today', _data['income_today'])),
                      const SizedBox(width: 8),
                      Expanded(child: _moneyMetric('Expenses today', _data['expenses_today'])),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text('Daily check-in', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                children: List.generate(5, (i) {
                  final value = i + 1;
                  return ChoiceChip(
                    label: Text('$value'),
                    selected: _mood == value,
                    onSelected: (_) => setState(() => _mood = value),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reflection,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(labelText: _start ? 'Daily intention / focus' : 'Reflection, wins and challenges'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _gratitude, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Gratitude / something worth noticing')),
              if (!_start) ...[
                const SizedBox(height: 10),
                TextField(controller: _tomorrowFocus, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'What should carry forward to tomorrow?')),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _save, icon: Icon(_start ? Icons.play_arrow_rounded : Icons.nights_stay_outlined), label: Text(_start ? 'Start My Day' : 'Close My Day')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _moneyMetric(String label, dynamic value) {
    final amount = double.tryParse((value ?? 0).toString()) ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      Text(NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(amount), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
    ]);
  }
}
