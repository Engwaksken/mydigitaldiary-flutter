import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import 'past_daily_plans_screen.dart';

class DailyPlannerScreen extends StatefulWidget {
  const DailyPlannerScreen({super.key});

  @override
  State<DailyPlannerScreen> createState() => _DailyPlannerScreenState();
}

class _DailyPlannerScreenState extends State<DailyPlannerScreen> {
  DateTime _date = DateTime.now();
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _plan = <String, dynamic>{};
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _wellbeingGoals = <Map<String, dynamic>>[];
  bool _loadingGoals = false;
  int _total = 0;
  int _completed = 0;
  int _pending = 0;
  int _timed = 0;
  int _progress = 0;

  static const List<String> _priorities = <String>['high', 'medium', 'low'];
  static const List<String> _repeatTypes = <String>[
    'once',
    'daily',
    'specific_days',
    'weekly',
    'monthly',
  ];
  static const List<String> _weekDays = <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    _date = DateTime(_date.year, _date.month, _date.day);
    _load();
    _loadWellbeingGoals();
  }

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  bool _truthy(dynamic value) =>
      value == true || value == 1 || value?.toString() == '1';

  List<Map<String, dynamic>> _extractItems(dynamic response) {
    if (response is! Map) return <Map<String, dynamic>>[];
    final raw = response['items'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Map<String, dynamic> _extractPlan(dynamic response) {
    if (response is Map && response['plan'] is Map) {
      return Map<String, dynamic>.from(response['plan'] as Map);
    }
    return <String, dynamic>{};
  }

  Future<void> _loadWellbeingGoals() async {
    if (mounted) setState(() => _loadingGoals = true);

    try {
      dynamic response = await ApiClient.instance.get(
        'personal-goals?per_page=100',
        cacheable: false,
      );

      if (response is Map && response['data'] is List) {
        response = response['data'];
      } else if (response is Map &&
          response['data'] is Map &&
          (response['data'] as Map)['data'] is List) {
        response = (response['data'] as Map)['data'];
      } else if (response is Map && response['items'] is List) {
        response = response['items'];
      }

      final goals = response is List
          ? response
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .where((goal) {
                final module = (goal['module'] ?? '').toString().toLowerCase();
                return const <String>{'exercise', 'diet', 'sleep'}.contains(module);
              })
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _wellbeingGoals = goals;
        _loadingGoals = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _wellbeingGoals = <Map<String, dynamic>>[];
        _loadingGoals = false;
      });
    }
  }

  int? _goalId(dynamic value) {
    if (value == null) return null;
    return value is int ? value : int.tryParse(value.toString());
  }

  String _goalLabel(Map<String, dynamic> goal) {
    final title = (goal['title'] ?? goal['name'] ?? 'Goal').toString();
    final module = (goal['module'] ?? '').toString().toLowerCase();

    final area = switch (module) {
      'exercise' => 'Exercise',
      'diet' => 'Diet',
      'sleep' => 'Sleep',
      _ => module,
    };

    return '$title · $area';
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
        'daily-planner?date=${_isoDate(_date)}',
        cacheable: false,
      );

      if (!mounted) return;

      final map = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      final items = _extractItems(map);

      setState(() {
        _plan = _extractPlan(map);
        _items = items;
        _total = int.tryParse('${map['total'] ?? items.length}') ?? items.length;
        _completed = int.tryParse('${map['completed'] ?? items.where((e) => _truthy(e['is_completed'])).length}') ?? 0;
        _pending = int.tryParse('${map['pending'] ?? items.where((e) => !_truthy(e['is_completed'])).length}') ?? 0;
        _timed = int.tryParse('${map['timed'] ?? items.where((e) => _hasTime(e['start_time'])).length}') ?? 0;
        _progress = int.tryParse('${map['progress'] ?? 0}') ?? 0;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load Daily Planner right now.';
      });
    }
  }

  bool _hasTime(dynamic value) => value != null && value.toString().trim().isNotEmpty;

  int? _timeToMinutes(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final pieces = raw.split(':');
    if (pieces.length < 2) return null;
    final hour = int.tryParse(pieces[0]);
    final minute = int.tryParse(pieces[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return (hour * 60) + minute;
  }

  int _taskDurationMinutes(Map<String, dynamic> item) {
    final start = _timeToMinutes(item['start_time']);
    final end = _timeToMinutes(item['end_time']);
    if (start == null || end == null || end <= start) return 0;
    return end - start;
  }

  int get _totalTimedMinutes => _items.fold<int>(
        0,
        (sum, item) => sum + _taskDurationMinutes(item),
      );

  String _durationLabel(int minutes) {
    if (minutes <= 0) return '0h';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  String _formatTime(dynamic value) {
    final minutes = _timeToMinutes(value);
    if (minutes == null) return '';
    final date = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
    return DateFormat('h:mm a').format(date);
  }

  String _repeatLabel(Map<String, dynamic> item) {
    final type = (item['repeat_type'] ?? 'once').toString();
    switch (type) {
      case 'daily':
        return 'Every day';
      case 'weekly':
        return 'Every week';
      case 'monthly':
        return 'Every month';
      case 'specific_days':
        final raw = item['repeat_days'];
        if (raw is List && raw.isNotEmpty) {
          return raw
              .map((day) => day.toString().substring(0, day.toString().length >= 3 ? 3 : day.toString().length))
              .join(' • ');
        }
        return 'Specific days';
      default:
        return 'Once';
    }
  }

  Future<void> _changeDate(int delta) async {
    setState(() => _date = _date.add(Duration(days: delta)));
    await _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    await _load();
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    try {
      final response = await ApiClient.instance.patch(
        'daily-planner/items/$id/toggle',
        <String, dynamic>{'occurrence_date': _isoDate(_date)},
      );

      await _load();

      if (response is Map) {
        final message = (response['message'] ??
                response['data']?['message'] ??
                response['wellbeing_message'])
            ?.toString()
            .trim();

        if ((message ?? '').isNotEmpty) {
          _message(message!);
        } else if (!_truthy(item['is_completed'])) {
          _message(
            'Task completed. If it is linked to an Exercise, Diet or Sleep goal, '
            'the server will add it to the matching wellbeing log automatically.',
          );
        }
      }
    } on ApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    final recurring = (item['repeat_type'] ?? 'once').toString() != 'once';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          recurring
              ? 'Remove this occurrence from ${DateFormat('d MMM yyyy').format(_date)}?'
              : 'This task will be deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (recurring) {
        await ApiClient.instance.deleteWithBody(
          'daily-planner/items/$id',
          <String, dynamic>{
            'occurrence_date': _isoDate(_date),
            'delete_scope': 'occurrence',
          },
        );
      } else {
        await ApiClient.instance.delete('daily-planner/items/$id');
      }
      await _load();
    } on ApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _saveDayPlan() async {
    final title = TextEditingController(text: (_plan['title'] ?? 'My Daily Plan').toString());
    final notes = TextEditingController(text: (_plan['notes'] ?? '').toString());
    final achievements = TextEditingController(text: (_plan['achievements'] ?? '').toString());
    final challenges = TextEditingController(text: (_plan['challenges'] ?? '').toString());

    try {
      final save = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Save Day Plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Plan title')),
                const SizedBox(height: 10),
                TextField(controller: notes, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Day notes')),
                const SizedBox(height: 10),
                TextField(controller: achievements, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Achievements')),
                const SizedBox(height: 10),
                TextField(controller: challenges, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Challenges')),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Day Plan'),
                ),
              ],
            ),
          ),
        ),
      );
      if (save != true) return;

      await ApiClient.instance.put(
        'daily-planner',
        <String, dynamic>{
          'plan_date': _isoDate(_date),
          'title': title.text.trim().isEmpty ? 'My Daily Plan' : title.text.trim(),
          'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
          'achievements': achievements.text.trim().isEmpty ? null : achievements.text.trim(),
          'challenges': challenges.text.trim().isEmpty ? null : challenges.text.trim(),
        },
      );
      await _load();
      _message('Day plan saved.');
    } on ApiException catch (error) {
      _message(error.message);
    } finally {
      title.dispose();
      notes.dispose();
      achievements.dispose();
      challenges.dispose();
    }
  }

  Future<void> _openTaskForm([Map<String, dynamic>? existing]) async {
    final title = TextEditingController(text: existing?['title']?.toString() ?? '');
    final description = TextEditingController(text: existing?['description']?.toString() ?? '');
    final achievements = TextEditingController(text: existing?['achievements']?.toString() ?? '');
    final challenges = TextEditingController(text: existing?['challenges']?.toString() ?? '');

    int? selectedGoalId = _goalId(
      existing?['personal_goal_id'] ??
          existing?['personal_goal']?['id'] ??
          existing?['goal_id'],
    );

    String priority = existing?['priority']?.toString() ?? 'medium';
    if (!_priorities.contains(priority)) priority = 'medium';

    String repeatType = existing?['repeat_type']?.toString() ?? 'once';
    if (!_repeatTypes.contains(repeatType)) repeatType = 'once';

    final repeatDays = <String>{};
    final rawDays = existing?['repeat_days'];
    if (rawDays is List) {
      repeatDays.addAll(rawDays.map((value) => value.toString().toLowerCase()));
    }

    TimeOfDay? start = _parseTimeOfDay(existing?['start_time']);
    TimeOfDay? end = _parseTimeOfDay(existing?['end_time']);
    DateTime startsOn = DateTime.tryParse(existing?['repeat_starts_on']?.toString() ?? '') ?? _date;
    DateTime? endsOn = DateTime.tryParse(existing?['repeat_ends_on']?.toString() ?? '');
    String? localError;

    try {
      final save = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: .92,
          minChildSize: .65,
          maxChildSize: .97,
          expand: false,
          builder: (context, scrollController) => Material(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: StatefulBuilder(
              builder: (context, setLocal) {
                Future<void> chooseStart() async {
                  final picked = await showTimePicker(context: context, initialTime: start ?? TimeOfDay.now());
                  if (picked != null) setLocal(() => start = picked);
                }

                Future<void> chooseEnd() async {
                  final picked = await showTimePicker(context: context, initialTime: end ?? start ?? TimeOfDay.now());
                  if (picked != null) setLocal(() => end = picked);
                }

                Future<void> chooseRepeatStart() async {
                  final picked = await showDatePicker(context: context, initialDate: startsOn, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setLocal(() => startsOn = picked);
                }

                Future<void> chooseRepeatEnd() async {
                  final picked = await showDatePicker(context: context, initialDate: endsOn ?? startsOn, firstDate: startsOn, lastDate: DateTime(2100));
                  if (picked != null) setLocal(() => endsOn = picked);
                }

                void validateAndClose() {
                  if (title.text.trim().isEmpty) {
                    setLocal(() => localError = 'Enter the task title.');
                    return;
                  }
                  if (start != null && end != null && _minutesOf(end!) <= _minutesOf(start!)) {
                    setLocal(() => localError = 'End time must be after start time.');
                    return;
                  }
                  if (repeatType == 'specific_days' && repeatDays.isEmpty) {
                    setLocal(() => localError = 'Choose at least one repeat day.');
                    return;
                  }
                  Navigator.pop(sheetContext, true);
                }

                final currentMinutes = start != null && end != null && _minutesOf(end!) > _minutesOf(start!)
                    ? _minutesOf(end!) - _minutesOf(start!)
                    : 0;

                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(width: 52, height: 5, decoration: BoxDecoration(color: const Color(0xFF94A3B8), borderRadius: BorderRadius.circular(999))),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 28),
                        children: [
                          Text(existing == null ? 'Add Task' : 'Edit Task', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 14),
                          TextField(controller: title, decoration: const InputDecoration(labelText: 'Task *')),
                          const SizedBox(height: 10),
                          TextField(controller: description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int?>(
                            initialValue: selectedGoalId,
                            decoration: InputDecoration(
                              labelText: 'Linked wellbeing goal',
                              helperText: _loadingGoals
                                  ? 'Loading Exercise, Diet and Sleep goals...'
                                  : 'Completing a linked task can automatically feed the matching wellbeing log.',
                            ),
                            items: <DropdownMenuItem<int?>>[
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('No linked wellbeing goal'),
                              ),
                              ..._wellbeingGoals.map(
                                (goal) => DropdownMenuItem<int?>(
                                  value: _goalId(goal['id']),
                                  child: Text(
                                    _goalLabel(goal),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setLocal(() => selectedGoalId = value),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: priority,
                            decoration: const InputDecoration(labelText: 'Priority'),
                            items: _priorities.map((value) => DropdownMenuItem(value: value, child: Text(value[0].toUpperCase() + value.substring(1)))).toList(growable: false),
                            onChanged: (value) => setLocal(() => priority = value ?? 'medium'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _timeField('Start time', start, chooseStart)),
                              const SizedBox(width: 10),
                              Expanded(child: _timeField('End time', end, chooseEnd)),
                            ],
                          ),
                          if (currentMinutes > 0) ...[
                            const SizedBox(height: 8),
                            Text('Task duration: ${_durationLabel(currentMinutes)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                          const SizedBox(height: 12),
                          TextField(controller: achievements, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Task achievement')),
                          const SizedBox(height: 10),
                          TextField(controller: challenges, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Task challenge')),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: repeatType,
                            decoration: const InputDecoration(labelText: 'Repeat'),
                            items: const [
                              DropdownMenuItem(value: 'once', child: Text('Once')),
                              DropdownMenuItem(value: 'daily', child: Text('Every day')),
                              DropdownMenuItem(value: 'specific_days', child: Text('Specific days')),
                              DropdownMenuItem(value: 'weekly', child: Text('Every week')),
                              DropdownMenuItem(value: 'monthly', child: Text('Every month')),
                            ],
                            onChanged: (value) => setLocal(() => repeatType = value ?? 'once'),
                          ),
                          if (repeatType == 'specific_days') ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: _weekDays.map((day) {
                                final selected = repeatDays.contains(day);
                                return FilterChip(
                                  selected: selected,
                                  label: Text(day.substring(0, 3).toUpperCase()),
                                  onSelected: (checked) => setLocal(() {
                                    checked ? repeatDays.add(day) : repeatDays.remove(day);
                                  }),
                                );
                              }).toList(growable: false),
                            ),
                          ],
                          if (repeatType != 'once') ...[
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Starts'),
                              subtitle: Text(DateFormat('dd MMM yyyy').format(startsOn)),
                              trailing: const Icon(Icons.calendar_month_outlined),
                              onTap: chooseRepeatStart,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Ends (optional)'),
                              subtitle: Text(endsOn == null ? 'No end date' : DateFormat('dd MMM yyyy').format(endsOn!)),
                              trailing: Wrap(
                                children: [
                                  if (endsOn != null) IconButton(onPressed: () => setLocal(() => endsOn = null), icon: const Icon(Icons.clear_rounded)),
                                  IconButton(onPressed: chooseRepeatEnd, icon: const Icon(Icons.calendar_month_outlined)),
                                ],
                              ),
                            ),
                          ],
                          if (localError != null) ...[
                            const SizedBox(height: 10),
                            Text(localError!, style: const TextStyle(color: Color(0xFFBE123C), fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: validateAndClose,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(existing == null ? 'Add Task' : 'Save Changes'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      if (save != true) return;

      final body = <String, dynamic>{
        'plan_date': _isoDate(_date),
        'title': title.text.trim(),
        'description': description.text.trim().isEmpty ? null : description.text.trim(),
        'achievements': achievements.text.trim().isEmpty ? null : achievements.text.trim(),
        'challenges': challenges.text.trim().isEmpty ? null : challenges.text.trim(),
        'priority': priority,
        'personal_goal_id': selectedGoalId,
        'start_time': start == null ? null : _apiTime(start!),
        'end_time': end == null ? null : _apiTime(end!),
        'repeat_type': repeatType,
        'repeat_days': repeatType == 'specific_days' ? repeatDays.toList(growable: false) : <String>[],
        'repeat_interval': 1,
        'repeat_starts_on': repeatType == 'once' ? null : _isoDate(startsOn),
        'repeat_ends_on': repeatType == 'once' || endsOn == null ? null : _isoDate(endsOn!),
        'occurrence_date': _isoDate(_date),
        'edit_scope': 'series',
      };

      if (existing == null) {
        await ApiClient.instance.post('daily-planner/items', body);
      } else {
        await ApiClient.instance.put('daily-planner/items/${existing['id']}', body);
      }
      await _load();
      _message(existing == null ? 'Task added.' : 'Task updated.');
    } on ApiException catch (error) {
      _message(error.message);
    } finally {
      title.dispose();
      description.dispose();
      achievements.dispose();
      challenges.dispose();
    }
  }

  TimeOfDay? _parseTimeOfDay(dynamic value) {
    final minutes = _timeToMinutes(value);
    return minutes == null ? null : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  int _minutesOf(TimeOfDay value) => value.hour * 60 + value.minute;

  String _apiTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Widget _timeField(String label, TimeOfDay? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value == null ? 'Any time' : value.format(context)),
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(radius: 14, child: Icon(icon, size: 17)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> item) {
    final done = _truthy(item['is_completed']);
    final start = _formatTime(item['start_time']);
    final end = _formatTime(item['end_time']);
    final duration = _taskDurationMinutes(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: done, onChanged: (_) => _toggle(item)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['title'] ?? 'Task').toString(),
                      style: TextStyle(fontWeight: FontWeight.w900, decoration: done ? TextDecoration.lineThrough : null, color: done ? const Color(0xFF94A3B8) : null),
                    ),
                    if ((item['description'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text((item['description'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (start.isNotEmpty)
                          _chip(end.isEmpty ? start : '$start – $end', Icons.schedule_rounded),
                        if (duration > 0)
                          _chip(_durationLabel(duration), Icons.hourglass_bottom_rounded),
                        _chip((item['priority'] ?? 'medium').toString(), Icons.flag_outlined),
                        _chip(_repeatLabel(item), (item['repeat_type'] ?? 'once').toString() == 'once' ? Icons.looks_one_outlined : Icons.repeat_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _openTaskForm(item);
                if (value == 'delete') _delete(item);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                PopupMenuItem(value: 'delete', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline_rounded), title: Text('Delete'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = _date.year == today.year && _date.month == today.month && _date.day == today.day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Planner'),
        actions: [
          IconButton(
            tooltip: 'Past tasks',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PastDailyPlansScreen()),
            ),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(tooltip: 'Save day plan', onPressed: _saveDayPlan, icon: const Icon(Icons.edit_calendar_outlined)),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Task'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 220), Center(child: CircularProgressIndicator())],
              )
            : _error != null && _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      const Icon(Icons.error_outline_rounded, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(onPressed: () => _changeDate(-1), icon: const Icon(Icons.chevron_left_rounded)),
                                  Expanded(
                                    child: InkWell(
                                      onTap: _pickDate,
                                      child: Column(
                                        children: [
                                          Text(DateFormat('EEEE, dd MMM yyyy').format(_date), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
                                          if (!isToday) const Text('Tap to choose date', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(onPressed: () => _changeDate(1), icon: const Icon(Icons.chevron_right_rounded)),
                                ],
                              ),
                              if (!isToday)
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      setState(() => _date = DateTime(today.year, today.month, today.day));
                                      await _load();
                                    },
                                    icon: const Icon(Icons.today_outlined),
                                    label: const Text('Today'),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text((_plan['title'] ?? 'My Daily Plan').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              if ((_plan['notes'] ?? '').toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text((_plan['notes'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(value: (_progress.clamp(0, 100)) / 100, minHeight: 8),
                              ),
                              const SizedBox(height: 5),
                              Text('$_progress% completed', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: MediaQuery.sizeOf(context).width >= 800 ? 4 : 2,
                        childAspectRatio: 1.55,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          _statCard('Total Tasks', '$_total', Icons.checklist_rounded),
                          _statCard('Completed', '$_completed', Icons.check_circle_outline_rounded),
                          _statCard('Pending', '$_pending', Icons.hourglass_empty_rounded),
                          _statCard('Timed Tasks', '$_timed (${_durationLabel(_totalTimedMinutes)})', Icons.schedule_rounded),
                        ],
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Planned time is calculated from tasks that have both a valid start and end time.',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 16),
                      Text(isToday ? "Today's Tasks" : 'Tasks for ${DateFormat('dd MMM yyyy').format(_date)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      const Text('Timed tasks are shown with their calculated duration.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      if (_items.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.event_note_outlined, size: 42),
                                SizedBox(height: 10),
                                Text('No tasks saved for this day.', style: TextStyle(fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Text('Tap Add Task to create a one-off or recurring task.', textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._items.map(_taskCard),
                    ],
                  ),
      ),
    );
  }
}
