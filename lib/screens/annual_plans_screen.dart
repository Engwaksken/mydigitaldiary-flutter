import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/annual_plan.dart';
import '../services/annual_planner_service.dart';
import '../services/goal_link_service.dart';
import '../services/api_client.dart';
import '../widgets/confirm_action_dialog.dart';

class AnnualPlansScreen extends StatefulWidget {
  const AnnualPlansScreen({super.key});
  @override
  State<AnnualPlansScreen> createState() => _AnnualPlansScreenState();
}

class _AnnualPlansScreenState extends State<AnnualPlansScreen> {
  final _service = AnnualPlannerService();
  final _search = TextEditingController();
  int _year = DateTime.now().year;
  String _status = '';
  String _period = '';
  int _month = 0;
  int _page = 1;
  int _perPage = 10;
  AnnualPlanSummary? _summary;
  bool _loading = true;
  String? _error;
  final Set<int> _selectedIds = {};
  bool _bulkDeleting = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.getPlans(
        year: _year, search: _search.text, status: _status, period: _period,
        month: _month, page: _page, perPage: _perPage,
      );
      if (!mounted) return;
      setState(() { _summary = result; _page = result.currentPage; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIds.isEmpty ? 'Annual Plans' : '${_selectedIds.length} selected'),
        leading: _selectedIds.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedIds.clear())),
        actions: [if (_selectedIds.isNotEmpty) IconButton(icon: _bulkDeleting ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.delete_outline), onPressed: _bulkDeleting ? null : _bulkDelete)],
      ),
      floatingActionButton: _selectedIds.isNotEmpty ? null : FloatingActionButton.extended(
        onPressed: () => _editPlan(), icon: const Icon(Icons.add), label: const Text('Add plan'),
      ),
      body: _loading && _summary == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _summary == null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final s = _summary!;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _stat('Total', s.total, Icons.list_alt),
          _stat('Completed', s.completed, Icons.check_circle_outline),
          _stat('Monthly', s.monthly, Icons.calendar_month),
          _stat('Reminders', s.withReminder, Icons.notifications_active_outlined),
        ]),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('$_year progress', style: const TextStyle(fontWeight: FontWeight.w700)), Text('${s.overallProgress}%', style: const TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 8), LinearProgressIndicator(value: s.overallProgress / 100),
        ]))),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: 'Search plans', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.tune), onPressed: _showFilters)),
          onSubmitted: (_) => _load(resetPage: true),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (_status.isNotEmpty) Chip(label: Text(_status.replaceAll('_', ' '))),
          if (_period.isNotEmpty) Chip(label: Text(_period == 'monthly' ? 'Monthly' : 'Annual')),
          if (_month > 0) Chip(label: Text(DateFormat.MMMM().format(DateTime(2000, _month)))),
          Chip(label: Text('$_perPage / page')),
        ]),
        const SizedBox(height: 10),
        if (_loading) const LinearProgressIndicator(),
        if (s.plans.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 44), child: Text('No plans match the selected filters.', textAlign: TextAlign.center))
        else
          ...s.plans.map(_planCard),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Showing ${s.from}–${s.to} of ${s.filteredTotal}', style: Theme.of(context).textTheme.bodySmall)),
          IconButton(onPressed: s.currentPage > 1 ? () { _page--; _load(); } : null, icon: const Icon(Icons.chevron_left)),
          Text('${s.currentPage}/${s.lastPage}'),
          IconButton(onPressed: s.currentPage < s.lastPage ? () { _page++; _load(); } : null, icon: const Icon(Icons.chevron_right)),
        ]),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _stat(String label, int value, IconData icon) {
    final palette = <String, (Color, Color)>{
      'Total': (const Color(0xFF0EA5E9), const Color(0xFFEFF8FF)),
      'Completed': (const Color(0xFF059669), const Color(0xFFECFDF5)),
      'Monthly': (const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
      'Reminders': (const Color(0xFFD97706), const Color(0xFFFFFBEB)),
    };
    final colors = palette[label] ?? (Theme.of(context).colorScheme.primary, const Color(0xFFF8FAFC));
    final accent = colors.$1;
    final background = colors.$2;
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 44) / 2,
      height: 82,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: accent, size: 18)),
          const SizedBox(width: 9),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value', style: const TextStyle(fontSize: 18, height: 1.0, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          ])),
        ]),
      ),
    );
  }

  Widget _planCard(AnnualPlan p) {
    final monthLabel = p.period == 'monthly' && p.month != null ? DateFormat.MMMM().format(DateTime(2000, p.month!)) : 'Annual';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 10), child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: _selectedIds.isNotEmpty ? Checkbox(value: _selectedIds.contains(p.id), onChanged: (_) => setState(() { if (_selectedIds.contains(p.id)) {_selectedIds.remove(p.id);} else {_selectedIds.add(p.id);} })) : Checkbox(value: p.isCompleted, onChanged: (v) => _toggle(p, v ?? false)),
          title: Text(p.title, style: TextStyle(fontWeight: FontWeight.w600, decoration: p.isCompleted ? TextDecoration.lineThrough : null)),
          subtitle: Text([
            '$monthLabel ${p.year}',
            p.status.replaceAll('_', ' '),
            if (p.targetDate != null) 'Target ${DateFormat('d MMM y').format(p.targetDate!)}',
            if (p.reminderAt != null) 'Reminder ${DateFormat('d MMM y, h:mm a').format(p.reminderAt!.toLocal())}',
            if (p.description?.trim().isNotEmpty == true) p.description!.trim(),
          ].join(' • ')),
          onLongPress: () => setState(() => _selectedIds.add(p.id)),
          onTap: _selectedIds.isEmpty ? null : () => setState(() { if (_selectedIds.contains(p.id)) {_selectedIds.remove(p.id);} else {_selectedIds.add(p.id);} }),
          trailing: _selectedIds.isNotEmpty ? null : PopupMenuButton<String>(
            onSelected: (a) { if (a == 'edit') _editPlan(p); if (a == 'delete') _delete(p); },
            itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [Expanded(child: LinearProgressIndicator(value: p.progressPercent / 100)), const SizedBox(width: 10), Text('${p.progressPercent}%')])),
      ])),
    );
  }

  Future<void> _showFilters() async {
    var status = _status, period = _period, month = _month, perPage = _perPage;
    final apply = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (c) => StatefulBuilder(builder: (c, setLocal) => Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.viewInsetsOf(c).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Filter Annual Plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Status'), items: const [DropdownMenuItem(value: '', child: Text('All statuses')), DropdownMenuItem(value: 'in_progress', child: Text('In progress')), DropdownMenuItem(value: 'pending', child: Text('Pending')), DropdownMenuItem(value: 'completed', child: Text('Completed'))], onChanged: (v) => setLocal(() => status = v ?? '')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: period, decoration: const InputDecoration(labelText: 'Period'), items: const [DropdownMenuItem(value: '', child: Text('All periods')), DropdownMenuItem(value: 'annually', child: Text('Annual')), DropdownMenuItem(value: 'monthly', child: Text('Monthly'))], onChanged: (v) => setLocal(() => period = v ?? '')),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(initialValue: month, decoration: const InputDecoration(labelText: 'Month'), items: [const DropdownMenuItem(value: 0, child: Text('All months')), ...List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat.MMMM().format(DateTime(2000, i + 1)))))], onChanged: (v) => setLocal(() => month = v ?? 0)),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(initialValue: perPage, decoration: const InputDecoration(labelText: 'Rows per page'), items: [10,25,50,100].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setLocal(() => perPage = v ?? 10)),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: OutlinedButton(onPressed: () { setLocal(() { status=''; period=''; month=0; perPage=10; }); }, child: const Text('Reset'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Apply')))]),
        ]),
      )),
    );
    if (apply == true) { setState(() { _status=status; _period=period; _month=month; _perPage=perPage; }); await _load(resetPage: true); }
  }

  Future<void> _toggle(AnnualPlan p, bool completed) async { try { await _service.toggle(p, completed); await _load(); } on ApiException catch (e) { _snack(e.message); } }
  Future<void> _delete(AnnualPlan p) async {
    final ok = await showAppConfirmDialog(context, title: 'Delete plan?', message: 'Delete “${p.title}”? This action cannot be undone.', confirmText: 'Delete plan');
    if (ok) { try { await _service.delete(p.id); await _load(); } on ApiException catch (e) { _snack(e.message); } }
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final ok = await showAppConfirmDialog(context, title: 'Delete selected plans?', message: 'Delete ${_selectedIds.length} selected plan${_selectedIds.length == 1 ? '' : 's'}? This action cannot be undone.', confirmText: 'Delete selected');
    if (!ok) return;
    setState(() => _bulkDeleting = true);
    try { await _service.bulkDelete(_selectedIds.toList()); _selectedIds.clear(); await _load(); } on ApiException catch (e) { _snack(e.message); } finally { if (mounted) setState(() => _bulkDeleting = false); }
  }

  Future<void> _editPlan([AnnualPlan? plan]) async {
    final title = TextEditingController(text: plan?.title ?? '');
    final description = TextEditingController(text: plan?.description ?? '');
    var year = plan?.year ?? _year;
    var period = plan?.period ?? 'annually';
    var month = plan?.month ?? DateTime.now().month;
    var progress = (plan?.progressPercent ?? 0).toDouble();
    DateTime? targetDate = plan?.targetDate;
    DateTime? reminderAt = plan?.reminderAt?.toLocal();
    int? personalGoalId = plan?.personalGoalId;
    List<GoalLinkOption> goalOptions = const [];
    try { goalOptions = await GoalLinkService().activeGoals(); } catch (_) {}
    if (!mounted) return;

    final save = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setLocal) => AlertDialog(
      title: Text(plan == null ? 'Add plan' : 'Edit plan'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Plan / goal *')),
        const SizedBox(height: 8),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          initialValue: personalGoalId,
          decoration: const InputDecoration(labelText: 'Linked goal (optional)'),
          items: [const DropdownMenuItem<int?>(value: null, child: Text('No linked goal')), ...goalOptions.map((g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.title, overflow: TextOverflow.ellipsis)))],
          onChanged: (v) => setLocal(() => personalGoalId = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(initialValue: year, decoration: const InputDecoration(labelText: 'Year'), items: List.generate(8, (i) => DateTime.now().year - 2 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(), onChanged: (v) => setLocal(() => year = v ?? year)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(initialValue: period, decoration: const InputDecoration(labelText: 'Plan period'), items: const [DropdownMenuItem(value: 'annually', child: Text('Annual')), DropdownMenuItem(value: 'monthly', child: Text('Monthly'))], onChanged: (v) => setLocal(() => period = v ?? 'annually')),
        if (period == 'monthly') ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(initialValue: month, decoration: const InputDecoration(labelText: 'Month'), items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat.MMMM().format(DateTime(2000, i + 1))))), onChanged: (v) => setLocal(() => month = v ?? month)),
        ],
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.flag_outlined), title: Text(targetDate == null ? 'Target date' : DateFormat('d MMM y').format(targetDate!)), trailing: targetDate == null ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setLocal(() => targetDate = null)), onTap: () async { final d = await showDatePicker(context: c, initialDate: targetDate ?? DateTime(year, month, 1), firstDate: DateTime(year,1,1), lastDate: DateTime(year,12,31)); if (d != null) setLocal(() => targetDate = d); }),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.notifications_active_outlined), title: Text(reminderAt == null ? 'Set reminder' : DateFormat('d MMM y, h:mm a').format(reminderAt!)), trailing: reminderAt == null ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setLocal(() => reminderAt = null)), onTap: () async {
          final d = await showDatePicker(context: c, initialDate: reminderAt ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(year + 2,12,31)); if (d == null) return;
          if (!c.mounted) return;
          final t = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(reminderAt ?? DateTime.now())); if (t != null) setLocal(() => reminderAt = DateTime(d.year,d.month,d.day,t.hour,t.minute));
        }),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Progress'), Text('${progress.round()}%')]),
        Slider(value: progress, min: 0, max: 100, divisions: 20, label: '${progress.round()}%', onChanged: (v) => setLocal(() => progress = v)),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: progress >= 100, title: const Text('Mark complete'), onChanged: (v) => setLocal(() => progress = v == true ? 100 : (progress >= 100 ? 95 : progress))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))],
    )));

    if (save != true || title.text.trim().isEmpty) return;
    try {
      if (plan == null) {
        await _service.create(title: title.text.trim(), year: year, period: period, month: period == 'monthly' ? month : null, description: description.text.trim().isEmpty ? null : description.text.trim(), targetDate: targetDate, reminderAt: reminderAt, progressPercent: progress.round(), personalGoalId: personalGoalId);
      } else {
        await _service.update(plan, title: title.text.trim(), year: year, period: period, month: period == 'monthly' ? month : null, description: description.text.trim().isEmpty ? null : description.text.trim(), targetDate: targetDate, reminderAt: reminderAt, progressPercent: progress.round(), personalGoalId: personalGoalId);
      }
      if (mounted) setState(() => _year = year);
      await _load(resetPage: true);
    } on ApiException catch (e) { _snack(e.message); }
  }

  void _snack(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }
}
