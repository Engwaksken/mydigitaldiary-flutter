import 'package:flutter/material.dart';

import '../models/daily_planner.dart';
import '../services/api_client.dart';
import '../services/daily_planner_service.dart';

class DailyPlannerScreen extends StatefulWidget {
  const DailyPlannerScreen({super.key});

  @override
  State<DailyPlannerScreen> createState() => _DailyPlannerScreenState();
}

class _DailyPlannerScreenState extends State<DailyPlannerScreen> {
  final DailyPlannerService _service = DailyPlannerService();

  DateTime _selectedDate = DateTime.now();
  DailyPlannerSnapshot? _snapshot;
  List<PersonalGoalOption> _goals = const <PersonalGoalOption>[];

  bool _loading = true;
  bool _goalsLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _dateKey => _formatDateOnly(_selectedDate);

  Future<void> _load({
    bool refreshGoals = false,
  }) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final futures = <Future<dynamic>>[
        _service.day(_dateKey),
      ];

      if (!_goalsLoaded || refreshGoals) {
        futures.add(_service.goals());
      }

      final results = await Future.wait(futures);

      if (!mounted) return;

      setState(() {
        _snapshot = results.first as DailyPlannerSnapshot;

        if (results.length > 1) {
          _goals = results[1] as List<PersonalGoalOption>;
          _goalsLoaded = true;
        }

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
        _error = 'Could not load the Daily Planner.';
      });
    }
  }

  Future<void> _changeDate(DateTime date) async {
    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
      );
    });

    await _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      await _changeDate(picked);
    }
  }

  Future<void> _openTaskEditor({
    DailyPlannerItem? item,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _TaskEditorSheet(
        service: _service,
        selectedDate: _selectedDate,
        goals: _goals,
        item: item,
      ),
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _toggle(DailyPlannerItem item) async {
    try {
      await _service.toggleTask(item);
      await _load();
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _delete(DailyPlannerItem item) async {
    var scope = 'series';

    if (item.isRecurring) {
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete recurring task'),
          content: const Text(
            'Choose what should be removed from this recurring task.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('occurrence'),
              child: const Text('Only this occurrence'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('future'),
              child: const Text('This and future'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('series'),
              child: const Text('Entire series'),
            ),
          ],
        ),
      );

      if (selected == null) return;
      scope = selected;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete task?'),
          content: Text(
            'Delete "${item.title}" from your planner?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      await _service.deleteTask(
        item,
        scope: scope,
      );
      await _load();
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _move(DailyPlannerItem item) async {
    if (item.isRecurring) {
      _showMessage(
        'Recurring tasks follow their repeat schedule. Edit the series instead.',
      );
      return;
    }

    final initial = _selectedDate.add(
      const Duration(days: 1),
    );

    final target = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(
        const Duration(days: 365),
      ),
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
    );

    if (target == null) return;

    try {
      await _service.moveTask(
        item,
        _formatDateOnly(target),
      );

      _showMessage('Task moved successfully.');
      await _load();
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Planner'),
        actions: [
          IconButton(
            tooltip: 'Today',
            onPressed: () => _changeDate(DateTime.now()),
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refreshGoals: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            12,
            12,
            12,
            100,
          ),
          children: [
            _DateHeader(
              selectedDate: _selectedDate,
              onPrevious: () => _changeDate(
                _selectedDate.subtract(
                  const Duration(days: 1),
                ),
              ),
              onNext: () => _changeDate(
                _selectedDate.add(
                  const Duration(days: 1),
                ),
              ),
              onPick: _pickDate,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              _ErrorCard(
                message: _error!,
                onRetry: _load,
              ),
            if (_loading && snapshot == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 72),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (snapshot != null) ...[
              _ProgressCard(snapshot: snapshot),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tasks',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.items.isEmpty)
                _EmptyDayCard(
                  onAdd: () => _openTaskEditor(),
                )
              else
                ...snapshot.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: _PlannerTaskCard(
                      item: item,
                      onToggle: () => _toggle(item),
                      onEdit: () => _openTaskEditor(item: item),
                      onDelete: () => _delete(item),
                      onMove: item.isRecurring ? null : () => _move(item),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DateHeader({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = _sameDay(
      selectedDate,
      DateTime.now(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous day',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                onTap: onPick,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Text(
                        isToday ? 'Today' : _weekdayName(selectedDate),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _friendlyDate(selectedDate),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next day',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final DailyPlannerSnapshot snapshot;

  const _ProgressCard({
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final progress = snapshot.progress.clamp(0, 100);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    snapshot.plan.title?.trim().isNotEmpty == true
                        ? snapshot.plan.title!
                        : 'My Daily Plan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '$progress%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  icon: Icons.list_alt_outlined,
                  label: '${snapshot.total} tasks',
                ),
                _MetricChip(
                  icon: Icons.check_circle_outline,
                  label: '${snapshot.completed} done',
                ),
                _MetricChip(
                  icon: Icons.pending_actions_outlined,
                  label: '${snapshot.pending} pending',
                ),
                _MetricChip(
                  icon: Icons.schedule_outlined,
                  label: '${snapshot.timed} timed',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        icon,
        size: 16,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PlannerTaskCard extends StatelessWidget {
  final DailyPlannerItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMove;

  const _PlannerTaskCard({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final priority = _priorityLabel(item.priority);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          10,
          10,
          6,
          10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: item.isCompleted,
              onChanged: (_) => onToggle(),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _TaskBadge(
                          icon: item.isRecurring
                              ? Icons.repeat
                              : Icons.schedule_outlined,
                          label: item.repeatLabel,
                        ),
                        if (item.personalGoalTitle != null)
                          _TaskBadge(
                            icon: Icons.track_changes_outlined,
                            label: item.personalGoalTitle!,
                          ),
                        _TaskBadge(
                          icon: Icons.flag_outlined,
                          label: priority,
                        ),
                        if (item.startTime != null)
                          _TaskBadge(
                            icon: Icons.access_time,
                            label: item.endTime == null
                                ? _formatTime12(item.startTime!)
                                : '${_formatTime12(item.startTime!)} – ${_formatTime12(item.endTime!)}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Task actions',
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'move':
                    onMove?.call();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                if (onMove != null)
                  const PopupMenuItem(
                    value: 'move',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.drive_file_move_outline),
                      title: Text('Move task'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TaskBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 28,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskEditorSheet extends StatefulWidget {
  final DailyPlannerService service;
  final DateTime selectedDate;
  final List<PersonalGoalOption> goals;
  final DailyPlannerItem? item;

  const _TaskEditorSheet({
    required this.service,
    required this.selectedDate,
    required this.goals,
    this.item,
  });

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _description;

  int? _goalId;
  String _priority = 'medium';
  String _repeatType = 'once';
  Set<String> _repeatDays = <String>{};
  DateTime? _repeatStarts;
  DateTime? _repeatEnds;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _editScope = 'series';

  bool _saving = false;
  String? _error;

  bool get _editing => widget.item != null;
  bool get _recurring => _repeatType != 'once';

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _title = TextEditingController(
      text: item?.title ?? '',
    );

    _description = TextEditingController(
      text: item?.description ?? '',
    );

    _goalId = item?.personalGoalId;
    _priority = item?.priority ?? 'medium';
    _repeatType = item?.repeatType ?? 'once';
    _repeatDays = item?.repeatDays.toSet() ?? <String>{};

    _repeatStarts = _parseDate(
      item?.repeatStartsOn ?? _formatDateOnly(widget.selectedDate),
    );

    _repeatEnds = _parseDate(
      item?.repeatEndsOn,
    );

    _startTime = _parseTime(item?.startTime);
    _endTime = _parseTime(item?.endTime);

    if (item?.isRecurring == true) {
      _editScope = 'series';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickTime({
    required bool start,
  }) async {
    final current = start ? _startTime : _endTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );

    if (picked == null) return;

    setState(() {
      if (start) {
        _startTime = picked;

        if (_endTime != null && _minutes(_endTime!) <= _minutes(picked)) {
          _endTime = null;
        }
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickRepeatDate({
    required bool starts,
  }) async {
    final initial = starts
        ? (_repeatStarts ?? widget.selectedDate)
        : (_repeatEnds ?? _repeatStarts ?? widget.selectedDate);

    final first =
        starts ? DateTime(2020) : (_repeatStarts ?? widget.selectedDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      if (starts) {
        _repeatStarts = picked;

        if (_repeatEnds != null && _repeatEnds!.isBefore(picked)) {
          _repeatEnds = null;
        }
      } else {
        _repeatEnds = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_repeatType == 'specific_days' && _repeatDays.isEmpty) {
      setState(() {
        _error = 'Choose at least one day for this recurring task.';
      });
      return;
    }

    if (_startTime != null &&
        _endTime != null &&
        _minutes(_endTime!) <= _minutes(_startTime!)) {
      setState(() {
        _error = 'End time must be after start time.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final item = widget.item;

    final draft = DailyPlannerTaskDraft(
      planDate: _formatDateOnly(widget.selectedDate),
      title: _title.text,
      description: _description.text,
      personalGoalId: _goalId,
      priority: _priority,
      startTime: _startTime == null ? null : _formatTime24(_startTime!),
      endTime: _endTime == null ? null : _formatTime24(_endTime!),
      repeatType: _repeatType,
      repeatDays: _repeatDays.toList(),
      repeatInterval: 1,
      repeatStartsOn: _recurring
          ? _formatDateOnly(
              _repeatStarts ?? widget.selectedDate,
            )
          : null,
      repeatEndsOn: _recurring && _repeatEnds != null
          ? _formatDateOnly(_repeatEnds!)
          : null,
      occurrenceDate: item?.occurrenceDate,
      editScope: item?.isRecurring == true ? _editScope : 'series',
    );

    try {
      if (item == null) {
        await widget.service.createTask(draft);
      } else {
        await widget.service.updateTask(
          item.id,
          draft,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Could not save this task.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editing ? 'Edit Task' : 'Add Planner Task',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _editing
                    ? 'Update this task and its repeat schedule.'
                    : 'Create it once and choose when it should repeat.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                autofocus: !_editing,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a task title.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.goals.isNotEmpty)
                DropdownButtonFormField<int?>(
                  initialValue: widget.goals.any(
                    (goal) => goal.id == _goalId,
                  )
                      ? _goalId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Goal',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No linked goal'),
                    ),
                    ...widget.goals.map(
                      (goal) => DropdownMenuItem<int?>(
                        value: goal.id,
                        child: Text(
                          goal.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _goalId = value);
                  },
                ),
              if (widget.goals.isNotEmpty) const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'low',
                    child: Text('Low'),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text('Medium'),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text('High'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _priority = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 430;

                  final start = _TimeField(
                    label: 'Start time',
                    value: _startTime,
                    onTap: () => _pickTime(start: true),
                    onClear: _startTime == null
                        ? null
                        : () => setState(
                              () => _startTime = null,
                            ),
                  );

                  final end = _TimeField(
                    label: 'End time',
                    value: _endTime,
                    onTap: () => _pickTime(start: false),
                    onClear: _endTime == null
                        ? null
                        : () => setState(
                              () => _endTime = null,
                            ),
                  );

                  if (narrow) {
                    return Column(
                      children: [
                        start,
                        const SizedBox(height: 10),
                        end,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: start),
                      const SizedBox(width: 10),
                      Expanded(child: end),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Repeat',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _repeatType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'once',
                    child: Text('Once'),
                  ),
                  DropdownMenuItem(
                    value: 'daily',
                    child: Text('Every day'),
                  ),
                  DropdownMenuItem(
                    value: 'specific_days',
                    child: Text('Specific days'),
                  ),
                  DropdownMenuItem(
                    value: 'weekly',
                    child: Text('Every week'),
                  ),
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Text('Every month'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _repeatType = value;

                    if (value == 'once') {
                      _repeatDays.clear();
                    }
                  });
                },
              ),
              if (_repeatType == 'specific_days') ...[
                const SizedBox(height: 12),
                Text(
                  'Repeat on',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: const [
                    ('monday', 'Mon'),
                    ('tuesday', 'Tue'),
                    ('wednesday', 'Wed'),
                    ('thursday', 'Thu'),
                    ('friday', 'Fri'),
                    ('saturday', 'Sat'),
                    ('sunday', 'Sun'),
                  ].map(
                    (day) {
                      final value = day.$1;
                      final label = day.$2;

                      return _DayChoice(
                        value,
                        label,
                      );
                    },
                  ).map((choice) {
                    return ChoiceChip(
                      label: Text(choice.label),
                      selected: _repeatDays.contains(choice.value),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _repeatDays.add(choice.value);
                          } else {
                            _repeatDays.remove(choice.value);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              if (_recurring) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 430;

                    final starts = _DateField(
                      label: 'Starts',
                      value: _repeatStarts,
                      onTap: () => _pickRepeatDate(starts: true),
                    );

                    final ends = _DateField(
                      label: 'Ends (optional)',
                      value: _repeatEnds,
                      onTap: () => _pickRepeatDate(starts: false),
                      onClear: _repeatEnds == null
                          ? null
                          : () => setState(
                                () => _repeatEnds = null,
                              ),
                    );

                    if (narrow) {
                      return Column(
                        children: [
                          starts,
                          const SizedBox(height: 10),
                          ends,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: starts),
                        const SizedBox(width: 10),
                        Expanded(child: ends),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                const _RecurringInfoCard(),
              ],
              if (_editing && widget.item!.isRecurring) ...[
                const SizedBox(height: 16),
                Text(
                  'Apply changes to',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                RadioGroup<String>(
                  groupValue: _editScope,
                  onChanged: _saving
                      ? (_) {}
                      : (value) {
                          if (value == null) return;
                          setState(() => _editScope = value);
                        },
                  child: const Column(
                    children: [
                      RadioListTile<String>(
                        value: 'occurrence',
                        title: Text(
                          'Only this occurrence',
                        ),
                        subtitle: Text(
                          'Keep the rest of the recurring series unchanged.',
                        ),
                      ),
                      RadioListTile<String>(
                        value: 'series',
                        title: Text(
                          'Entire series',
                        ),
                        subtitle: Text(
                          'Update the recurrence rule for the series.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : (_editing ? 'Save Changes' : 'Save Task'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChoice {
  final String value;
  final String label;

  const _DayChoice(
    this.value,
    this.label,
  );
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: onClear == null
              ? const Icon(Icons.schedule_outlined)
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(
          value == null ? 'Not set' : value!.format(context),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(
          value == null ? 'No end date' : _friendlyDate(value!),
        ),
      ),
    );
  }
}

class _RecurringInfoCard extends StatelessWidget {
  const _RecurringInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 19,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This task is created once. Completing it on one scheduled date does not complete future occurrences.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDayCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyDayCard({
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 34,
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'No tasks for this day',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Add a one-off task or create a recurring task that automatically appears on the days you choose.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function({
    bool refreshGoals,
  }) onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            TextButton(
              onPressed: () => onRetry(
                refreshGoals: false,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateOnly(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(
    value.length >= 10 ? value.substring(0, 10) : value,
  );
}

TimeOfDay? _parseTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  final parts = value.split(':');
  if (parts.length < 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);

  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }

  return TimeOfDay(
    hour: hour,
    minute: minute,
  );
}

String _formatTime24(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

String _formatTime12(String value) {
  final time = _parseTime(value);
  if (time == null) return value;

  final period = time.hour >= 12 ? 'PM' : 'AM';
  final hour =
      time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);

  return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
}

int _minutes(TimeOfDay value) {
  return value.hour * 60 + value.minute;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _weekdayName(DateTime date) {
  const values = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  return values[date.weekday - 1];
}

String _friendlyDate(DateTime date) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _priorityLabel(String value) {
  switch (value.toLowerCase()) {
    case 'high':
      return 'High priority';
    case 'low':
      return 'Low priority';
    default:
      return 'Medium priority';
  }
}
