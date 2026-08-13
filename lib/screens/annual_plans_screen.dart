import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/annual_plan.dart';
import '../services/annual_planner_service.dart';
import '../services/api_client.dart';

class AnnualPlansScreen extends StatefulWidget {
  const AnnualPlansScreen({super.key});

  @override
  State<AnnualPlansScreen> createState() => _AnnualPlansScreenState();
}

class _AnnualPlansScreenState extends State<AnnualPlansScreen> {
  final _service = AnnualPlannerService();
  final _search = TextEditingController();
  int _year = DateTime.now().year;
  AnnualPlanSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _service.getPlans(year: _year, search: _search.text);
      if (!mounted) return;
      setState(() => _summary = summary);
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
        title: const Text('Annual Plans'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Select year',
            initialValue: _year,
            onSelected: (year) {
              setState(() => _year = year);
              _load();
            },
            itemBuilder: (_) {
              final years = <int>{
                DateTime.now().year,
                ...(_summary?.availableYears ?? const <int>[]),
                _year,
              }.toList()..sort((a, b) => b.compareTo(a));
              return years.map((y) => PopupMenuItem(value: y, child: Text('$y'))).toList();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(child: Text('$_year', style: const TextStyle(fontWeight: FontWeight.w600))),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editPlan(),
        icon: const Icon(Icons.add),
        label: const Text('Add plan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final s = _summary!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$_year progress', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${s.overallProgress}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: s.overallProgress / 100),
                const SizedBox(height: 8),
                Text('${s.completed} completed of ${s.total} annual plans'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search annual plans',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _search.clear();
                      _load();
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onSubmitted: (_) => _load(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (s.plans.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Text(
              'No annual plans yet. Tap “Add plan” to set a goal for the year.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ...s.plans.map(_planCard),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _planCard(AnnualPlan plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Checkbox(
                value: plan.isCompleted,
                onChanged: (value) => _toggle(plan, value ?? false),
              ),
              title: Text(
                plan.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text([
                if (plan.targetDate != null) 'Target ${DateFormat('d MMM y').format(plan.targetDate!)}',
                if (plan.description?.trim().isNotEmpty == true) plan.description!.trim(),
              ].join(' • ')),
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') _editPlan(plan);
                  if (action == 'delete') _delete(plan);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(child: LinearProgressIndicator(value: plan.progressPercent / 100)),
                  const SizedBox(width: 12),
                  SizedBox(width: 42, child: Text('${plan.progressPercent}%', textAlign: TextAlign.right)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(AnnualPlan plan, bool completed) async {
    try {
      await _service.toggle(plan, completed);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(AnnualPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete annual plan?'),
        content: Text(plan.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(plan.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editPlan([AnnualPlan? plan]) async {
    final title = TextEditingController(text: plan?.title ?? '');
    final description = TextEditingController(text: plan?.description ?? '');
    var year = plan?.year ?? _year;
    var progress = (plan?.progressPercent ?? 0).toDouble();
    DateTime? targetDate = plan?.targetDate;

    final save = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text(plan == null ? 'Add annual plan' : 'Edit annual plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Plan / goal *')),
                const SizedBox(height: 8),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: year,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: List.generate(8, (i) => DateTime.now().year - 2 + i)
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) => setLocal(() => year = v ?? year),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(targetDate == null ? 'Target date (optional)' : DateFormat('d MMMM y').format(targetDate!)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: c,
                      initialDate: targetDate ?? DateTime(year, 12, 31),
                      firstDate: DateTime(year, 1, 1),
                      lastDate: DateTime(year, 12, 31),
                    );
                    if (picked != null) setLocal(() => targetDate = picked);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const Text('Progress'), Text('${progress.round()}%')],
                ),
                Slider(
                  value: progress,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${progress.round()}%',
                  onChanged: (v) => setLocal(() => progress = v),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: progress >= 100,
                  title: const Text('Mark plan complete'),
                  subtitle: const Text('Completed plans are automatically set to 100%'),
                  onChanged: (v) => setLocal(() => progress = v == true ? 100 : (progress >= 100 ? 95 : progress)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (save != true || title.text.trim().isEmpty) return;
    try {
      if (plan == null) {
        await _service.create(
          title: title.text.trim(),
          year: year,
          description: description.text.trim().isEmpty ? null : description.text.trim(),
          targetDate: targetDate,
          progressPercent: progress.round(),
        );
      } else {
        await _service.update(
          plan,
          title: title.text.trim(),
          year: year,
          description: description.text.trim().isEmpty ? null : description.text.trim(),
          targetDate: targetDate,
          progressPercent: progress.round(),
        );
      }
      if (mounted) setState(() => _year = year);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
