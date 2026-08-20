import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_plan.dart';
import '../models/reminder.dart';
import '../services/api_client.dart';
import '../services/daily_planner_service.dart';
import '../services/goal_link_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../widgets/confirm_action_dialog.dart';

class DailyPlannerScreen extends StatefulWidget {
  const DailyPlannerScreen({super.key});

  @override
  State<DailyPlannerScreen> createState() => _DailyPlannerScreenState();
}

class _DailyPlannerScreenState extends State<DailyPlannerScreen> {
  final _service = DailyPlannerService();
  DateTime _date = DateTime.now();
  DailyPlan? _plan;
  DailyPlanHistoryPage? _history;
  int _historyPage = 1;
  int _tabIndex = 0;
  final _historySearch = TextEditingController();
  String _historyPeriod = 'all';
  DateTime? _historyFrom;
  DateTime? _historyTo;
  int _historyPerPage = 10;
  bool _loading = true;
  bool _historyLoading = false;
  String? _error;
  final Set<int> _selectedTaskIds = {};
  bool _bulkDeleting = false;

  Color get _primary => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _historySearch.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPlan(), _loadHistory()]);
  }

  Future<void> _loadPlan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await _service.getPlan(_date);
      if (mounted) setState(() => _plan = plan);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Offline. No saved planner copy is available for this date yet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory({int? page}) async {
    if (page != null) _historyPage = page;
    setState(() => _historyLoading = true);
    try {
      final history = await _service.getHistory(
        page: _historyPage,
        search: _historySearch.text,
        period: _historyPeriod,
        from: _historyFrom,
        to: _historyTo,
        perPage: _historyPerPage,
      );
      if (mounted) setState(() => _history = history);
    } catch (_) {
      // History should not block the planner itself.
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _changeDate(DateTime date) async {
    setState(() => _date = DateTime(date.year, date.month, date.day));
    await _loadPlan();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) await _changeDate(selected);
  }

  String _timeLabel(String? value) {
    if (value == null || value.isEmpty) return 'No time';
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return value;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final p = value.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  String? _timeValue(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedTaskIds.isEmpty ? 'Daily Planner' : '${_selectedTaskIds.length} selected'),
        leading: _selectedTaskIds.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedTaskIds.clear())),
        actions: [
          if (_selectedTaskIds.isNotEmpty) IconButton(tooltip: 'Delete selected', onPressed: _bulkDeleting ? null : _bulkDeleteTasks, icon: _bulkDeleting ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.delete_outline)),
          if (_selectedTaskIds.isEmpty) IconButton(
            onPressed: _pickDate,
            tooltip: 'Choose date',
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? _errorView()
              : _body(),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _primary),
                onPressed: _loadPlan,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );

  Widget _body() {
    final plan = _plan!;
    final items = [...plan.items]
      ..sort((a, b) {
        if (a.startTime == null && b.startTime == null) return a.title.compareTo(b.title);
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return a.startTime!.compareTo(b.startTime!);
      });

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          _dateHeader(),
          const SizedBox(height: 14),
          _actionBar(),
          const SizedBox(height: 14),
          _stats(plan),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.today_outlined), label: Text('Tasks')),
              ButtonSegment(value: 1, icon: Icon(Icons.history), label: Text('Past Tasks')),
            ],
            selected: {_tabIndex},
            showSelectedIcon: false,
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? Colors.white : _primary),
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? _primary : null),
            ),
            onSelectionChanged: (value) {
              setState(() => _tabIndex = value.first);
              if (_tabIndex == 1) _loadHistory(page: 1);
            },
          ),
          const SizedBox(height: 16),
          if (_tabIndex == 0) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tasks by time',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('${plan.total} task${plan.total == 1 ? '' : 's'}'),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty) _emptyTasks() else ...items.map(_taskCard),
            if ((plan.notes ?? '').trim().isNotEmpty || (plan.achievements ?? '').trim().isNotEmpty || (plan.challenges ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              _notesCard(plan),
            ],
          ] else
            _historySection(),
        ],
      ),
    );
  }

  Widget _dateHeader() {
    final today = DateUtils.isSameDay(_date, DateTime.now());
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => _changeDate(_date.subtract(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous day',
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE').format(_date),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(DateFormat('d MMMM y').format(_date)),
                  if (today)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text('Today', style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => _changeDate(_date.add(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next day',
        ),
      ],
    );
  }

  Widget _actionBar() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _primary),
            onPressed: () => _taskModal(),
            icon: const Icon(Icons.add_task),
            label: const Text('Add Task'),
          ),
          FilledButton.tonalIcon(
            onPressed: _dayPlanModal,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Day Plan'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: _primary),
            onPressed: () => _changeDate(DateTime.now()),
            icon: const Icon(Icons.today_outlined),
            label: const Text('Today'),
          ),
        ],
      );

  Widget _stats(DailyPlan p) {
    return Column(children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.15,
        children: [
          _statCard('Total', p.total, Icons.list_alt_outlined, const Color(0xFF0EA5E9)),
          _statCard('Completed', p.completed, Icons.task_alt, const Color(0xFF10B981)),
          _statCard('Pending', p.pending, Icons.pending_actions_outlined, const Color(0xFFF59E0B)),
          _statCard('Timed', p.timed, Icons.schedule, const Color(0xFF8B5CF6)),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        decoration: BoxDecoration(color: _primary.withValues(alpha: .05), borderRadius: BorderRadius.circular(14), border: Border(left: BorderSide(color: _primary, width: 4), top: BorderSide(color: _primary.withValues(alpha: .12)), right: BorderSide(color: _primary.withValues(alpha: .12)), bottom: BorderSide(color: _primary.withValues(alpha: .12)))),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Day progress', style: TextStyle(fontWeight: FontWeight.w700)), Text('${p.progress}%', style: TextStyle(color: _primary, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 7),
          LinearProgressIndicator(value: p.progress / 100, minHeight: 7, color: _primary, borderRadius: BorderRadius.circular(99)),
        ]),
      ),
    ]);
  }

  Widget _statCard(String label, int value, IconData icon, Color accent) {
    final backgrounds = <String, Color>{
      'Total': const Color(0xFFEFF8FF),
      'Completed': const Color(0xFFECFDF5),
      'Pending': const Color(0xFFFFFBEB),
      'Timed': const Color(0xFFF5F3FF),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: backgrounds[label] ?? const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(13),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: accent, size: 17)),
        const SizedBox(width: 8),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: const TextStyle(fontSize: 17, height: 1.0, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        ])),
      ]),
    );
  }

  Widget _emptyTasks() => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            children: [
              Icon(Icons.event_note_outlined, color: _primary, size: 38),
              const SizedBox(height: 10),
              const Text('No tasks saved for this day.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _primary),
                onPressed: () => _taskModal(),
                icon: const Icon(Icons.add),
                label: const Text('Add Task'),
              ),
            ],
          ),
        ),
      );

  Widget _taskCard(DailyPlanItem item) {
    final timed = item.startTime != null && item.startTime!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => setState(() => _selectedTaskIds.add(item.id)),
        onTap: () { if (_selectedTaskIds.isNotEmpty) { setState(() { if (_selectedTaskIds.contains(item.id)) {_selectedTaskIds.remove(item.id);} else {_selectedTaskIds.add(item.id);} }); } else { _taskModal(item: item); } },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                activeColor: _primary,
                value: _selectedTaskIds.isNotEmpty ? _selectedTaskIds.contains(item.id) : item.isCompleted,
                onChanged: (_) { if (_selectedTaskIds.isNotEmpty) { setState(() { if (_selectedTaskIds.contains(item.id)) {_selectedTaskIds.remove(item.id);} else {_selectedTaskIds.add(item.id);} }); } else { _toggle(item); } },
              ),
              SizedBox(
                width: 76,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timed ? _timeLabel(item.startTime) : 'Any time',
                        style: TextStyle(color: timed ? _primary : null, fontWeight: FontWeight.w800),
                      ),
                      if (item.endTime != null)
                        Text('to ${_timeLabel(item.endTime)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _pill(item.priority.toUpperCase()),
                          if (item.offlinePending) _pill('WAITING TO SYNC'),
                          if ((item.description ?? '').trim().isNotEmpty)
                            Text(
                              item.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if ((item.achievements ?? '').trim().isNotEmpty) Text('Achievement: ${item.achievements}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                          if ((item.challenges ?? '').trim().isNotEmpty) Text('Challenge: ${item.challenges}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _taskModal(item: item);
                  if (value == 'delete') _delete(item);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit Task')),
                  PopupMenuItem(value: 'delete', child: Text('Delete Task')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(fontSize: 10, color: _primary, fontWeight: FontWeight.w700)),
      );

  Widget _notesCard(DailyPlan plan) => Card(
        child: ListTile(
          leading: Icon(Icons.notes_outlined, color: _primary),
          title: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text([if ((plan.notes ?? '').trim().isNotEmpty) 'Notes: ${plan.notes}', if ((plan.achievements ?? '').trim().isNotEmpty) 'Achievements: ${plan.achievements}', if ((plan.challenges ?? '').trim().isNotEmpty) 'Challenges: ${plan.challenges}'].join('\n\n')),
          trailing: const Icon(Icons.edit_outlined),
          onTap: _dayPlanModal,
        ),
      );

  Widget _historySection() {
    final history = _history;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Past Tasks',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (history != null) Text('${history.total} saved'),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _historySearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search past tasks',
            hintText: 'Task, description, plan title or notes',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _historySearch.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _historySearch.clear();
                      _loadHistory(page: 1);
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          onSubmitted: (_) => _loadHistory(page: 1),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _historyPeriod,
                decoration: const InputDecoration(labelText: 'Period'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All past dates')),
                  DropdownMenuItem(value: '7_days', child: Text('Last 7 days')),
                  DropdownMenuItem(value: '30_days', child: Text('Last 30 days')),
                  DropdownMenuItem(value: '90_days', child: Text('Last 90 days')),
                  DropdownMenuItem(value: 'this_month', child: Text('This month')),
                  DropdownMenuItem(value: 'last_month', child: Text('Last month')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom range')),
                ],
                onChanged: (value) async {
                  setState(() {
                    _historyPeriod = value ?? 'all';
                    if (_historyPeriod != 'custom') {
                      _historyFrom = null;
                      _historyTo = null;
                    }
                  });
                  await _loadHistory(page: 1);
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: DropdownButtonFormField<int>(
                initialValue: _historyPerPage,
                decoration: const InputDecoration(labelText: 'Rows'),
                items: const [10, 25, 50, 100]
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                    .toList(),
                onChanged: (value) {
                  setState(() => _historyPerPage = value ?? 10);
                  _loadHistory(page: 1);
                },
              ),
            ),
          ],
        ),
        if (_historyPeriod == 'custom') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickHistoryDate(true),
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(_historyFrom == null ? 'From' : DateFormat('d MMM y').format(_historyFrom!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickHistoryDate(false),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_historyTo == null ? 'To' : DateFormat('d MMM y').format(_historyTo!)),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (_historyLoading)
          LinearProgressIndicator(color: _primary)
        else if (history == null || history.data.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No past tasks match the selected filters.'),
            ),
          )
        else ...[
          ...history.data.map(
            (row) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _primary.withValues(alpha: .10),
                  child: Text(
                    '${row.progress}%',
                    style: TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(
                  DateFormat('EEE, d MMM y').format(row.date),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${row.completed}/${row.total} completed${row.title.isNotEmpty ? ' • ${row.title}' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  setState(() => _tabIndex = 0);
                  await _changeDate(row.date);
                },
              ),
            ),
          ),
          if (history.lastPage > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: history.currentPage > 1
                      ? () => _loadHistory(page: history.currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Page ${history.currentPage} of ${history.lastPage}'),
                IconButton(
                  onPressed: history.currentPage < history.lastPage
                      ? () => _loadHistory(page: history.currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Future<void> _pickHistoryDate(bool isFrom) async {
    final initial = isFrom ? (_historyFrom ?? DateTime.now()) : (_historyTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _historyFrom = picked;
        if (_historyTo != null && _historyTo!.isBefore(picked)) _historyTo = picked;
      } else {
        _historyTo = picked;
        if (_historyFrom != null && _historyFrom!.isAfter(picked)) _historyFrom = picked;
      }
    });
    await _loadHistory(page: 1);
  }

  Future<void> _toggle(DailyPlanItem item) async {
    try {
      await _service.toggle(item.id, baseUpdatedAt: item.updatedAt);
      await Future.wait([_loadPlan(), _loadHistory()]);
    } on ApiException catch (e) {
      _message(e.message, error: true);
    }
  }

  Future<void> _delete(DailyPlanItem item) async {
    final ok = await showAppConfirmDialog(context, title: 'Delete task?', message: 'Delete “${item.title}”? This action cannot be undone.', confirmText: 'Delete task');
    if (!ok) return;
    try {
      await _service.delete(item.id, baseUpdatedAt: item.updatedAt);
      _message('Task deleted.');
      await Future.wait([_loadPlan(), _loadHistory()]);
    } on ApiException catch (e) { _message(e.message, error: true); }
  }

  Future<void> _bulkDeleteTasks() async {
    if (_selectedTaskIds.isEmpty) return;
    final ok = await showAppConfirmDialog(context, title: 'Delete selected tasks?', message: 'Delete ${_selectedTaskIds.length} selected task${_selectedTaskIds.length == 1 ? '' : 's'}? This action cannot be undone.', confirmText: 'Delete selected');
    if (!ok) return;
    setState(() => _bulkDeleting = true);
    try {
      await _service.bulkDeleteItems(_selectedTaskIds.toList());
      _selectedTaskIds.clear();
      await Future.wait([_loadPlan(), _loadHistory()]);
    } on ApiException catch (e) { _message(e.message, error: true); } finally { if (mounted) setState(() => _bulkDeleting = false); }
  }

  Future<void> _dayPlanModal() async {
    final plan = _plan!;
    final title = TextEditingController(text: plan.title);
    final notes = TextEditingController(text: plan.notes ?? '');
    final achievements = TextEditingController(text: plan.achievements ?? '');
    final challenges = TextEditingController(text: plan.challenges ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Save Day Plan', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(DateFormat('EEEE, d MMMM y').format(_date)),
            const SizedBox(height: 16),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Plan title')),
            const SizedBox(height: 12),
            TextField(controller: notes, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Day notes')),
            const SizedBox(height: 12),
            TextField(controller: achievements, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Achievements', hintText: 'What did you achieve today?')),
            const SizedBox(height: 12),
            TextField(controller: challenges, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Challenges', hintText: 'What challenges did you face?')),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.primary),
                onPressed: () => Navigator.pop(c, true),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Day Plan'),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await _service.updatePlan(
        _date,
        title: title.text.trim().isEmpty ? 'My Daily Plan' : title.text.trim(),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        achievements: achievements.text.trim().isEmpty ? null : achievements.text.trim(),
        challenges: challenges.text.trim().isEmpty ? null : challenges.text.trim(),
      );
      _message('Day plan saved.');
      await Future.wait([_loadPlan(), _loadHistory()]);
    } on ApiException catch (e) {
      _message(e.message, error: true);
    }
  }

  Future<void> _taskModal({DailyPlanItem? item}) async {
    final editing = item != null;
    final title = TextEditingController(text: item?.title ?? '');
    final desc = TextEditingController(text: item?.description ?? '');
    final achievements = TextEditingController(text: item?.achievements ?? '');
    final challenges = TextEditingController(text: item?.challenges ?? '');
    DateTime taskDate = _date;
    var priority = item?.priority ?? 'medium';
    TimeOfDay? start = _parseTime(item?.startTime);
    TimeOfDay? end = _parseTime(item?.endTime);
    var remind = false;
    int? personalGoalId = item?.personalGoalId;
    List<GoalLinkOption> goalOptions = const [];
    try { goalOptions = await GoalLinkService().activeGoals(); } catch (_) {}
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editing ? 'Edit Task' : 'Add Task', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(controller: title, autofocus: !editing, decoration: const InputDecoration(labelText: 'Task *')),
                const SizedBox(height: 10),
                TextField(controller: desc, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: personalGoalId,
                  decoration: const InputDecoration(labelText: 'Linked goal (optional)'),
                  items: [const DropdownMenuItem<int?>(value: null, child: Text('No linked goal')), ...goalOptions.map((g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.title, overflow: TextOverflow.ellipsis)))],
                  onChanged: (v) => setLocal(() => personalGoalId = v),
                ),
                const SizedBox(height: 10),
                ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.calendar_month_outlined, color: Theme.of(c).colorScheme.primary), title: const Text('Task date'), subtitle: Text(DateFormat('EEE, d MMM y').format(taskDate)), trailing: const Icon(Icons.edit_calendar_outlined), onTap: () async { final picked = await showDatePicker(context: c, initialDate: taskDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days:3650))); if (picked != null) setLocal(() => taskDate = picked); }),
                const SizedBox(height: 6),
                TextField(controller: achievements, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Task Achievement')),
                const SizedBox(height: 10),
                TextField(controller: challenges, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Task Challenge')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                  ],
                  onChanged: (v) => setLocal(() => priority = v ?? 'medium'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule, color: Theme.of(c).colorScheme.primary),
                  title: Text(start == null ? 'Set start time' : 'Start: ${start!.format(c)}'),
                  trailing: start == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setLocal(() => start = null)),
                  onTap: () async {
                    final picked = await showTimePicker(context: c, initialTime: start ?? TimeOfDay.now());
                    if (picked != null) setLocal(() => start = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.timelapse, color: Theme.of(c).colorScheme.primary),
                  title: Text(end == null ? 'Set end time' : 'End: ${end!.format(c)}'),
                  trailing: end == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setLocal(() => end = null)),
                  onTap: () async {
                    final picked = await showTimePicker(context: c, initialTime: end ?? start ?? TimeOfDay.now());
                    if (picked != null) setLocal(() => end = picked);
                  },
                ),
                if (!editing)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Theme.of(c).colorScheme.primary,
                    value: remind,
                    onChanged: start == null ? null : (v) => setLocal(() => remind = v),
                    title: const Text('Remind me'),
                    subtitle: const Text('Popup starts 30 minutes before the task time.'),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.primary),
                    onPressed: () {
                      if (title.text.trim().isEmpty) return;
                      Navigator.pop(c, true);
                    },
                    icon: Icon(editing ? Icons.save_outlined : Icons.add_task),
                    label: Text(editing ? 'Save Changes' : 'Add Task'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true || title.text.trim().isEmpty) return;
    if (start != null && end != null) {
      final startMinutes = start!.hour * 60 + start!.minute;
      final endMinutes = end!.hour * 60 + end!.minute;
      if (endMinutes <= startMinutes) {
        _message('End time must be after start time.', error: true);
        return;
      }
    }

    try {
      if (editing) {
        final savedItem = await _service.updateItem(
          item.id,
          title: title.text.trim(),
          description: desc.text.trim().isEmpty ? null : desc.text.trim(),
          achievements: achievements.text.trim().isEmpty ? null : achievements.text.trim(),
          challenges: challenges.text.trim().isEmpty ? null : challenges.text.trim(),
          planDate: taskDate,
          priority: priority,
          startTime: _timeValue(start),
          endTime: _timeValue(end),
          personalGoalId: personalGoalId,
          baseUpdatedAt: item.updatedAt,
        );
        _message(savedItem.offlinePending ? 'Task updated on this device. It will sync when you reconnect.' : 'Task updated.');
      } else {
        final savedItem = await _service.addItem(
          taskDate,
          title: title.text.trim(),
          description: desc.text.trim().isEmpty ? null : desc.text.trim(),
          achievements: achievements.text.trim().isEmpty ? null : achievements.text.trim(),
          challenges: challenges.text.trim().isEmpty ? null : challenges.text.trim(),
          priority: priority,
          startTime: _timeValue(start),
          endTime: _timeValue(end),
          personalGoalId: personalGoalId,
        );
        if (remind && start != null) await _createReminder(title.text.trim(), desc.text.trim(), start!);
        _message(savedItem.offlinePending ? 'Task saved on this device. It will sync when you reconnect.' : 'Task added.');
      }
      await Future.wait([_loadPlan(), _loadHistory()]);
    } on ApiException catch (e) {
      _message(e.message, error: true);
    }
  }

  Future<void> _createReminder(String title, String description, TimeOfDay start) async {
    final due = DateTime(_date.year, _date.month, _date.day, start.hour, start.minute);
    if (!due.isAfter(DateTime.now())) return;
    final reminder = await ReminderService().create(
      Reminder(
        id: 0,
        title: 'Daily Planner: $title',
        module: 'daily_planner',
        message: description.isEmpty ? 'Upcoming Daily Planner task' : description,
        frequency: 'once',
        intervalMinutes: null,
        nextRunAt: due,
        channel: 'database',
        isActive: true,
        alarmEnabled: true,
      ),
    );
    await NotificationService.instance.scheduleReminder(reminder);
  }
}
