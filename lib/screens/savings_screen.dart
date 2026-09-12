import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/personal_management_service.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final _service = const PersonalManagementService();
  List<Map<String, dynamic>> _goals = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _n(dynamic value) =>
      double.tryParse((value ?? '0').toString().replaceAll(',', '')) ?? 0;

  String _money(dynamic value) =>
      NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(_n(value));

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final response = await _service.savings();
      dynamic raw = response['goals'] ?? response['data'] ?? response;
      if (raw is Map && raw['data'] is List) raw = raw['data'];
      final goals = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false)
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() { _goals = goals; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load savings.'; });
    }
  }

  Future<void> _addContribution(Map<String, dynamic> goal) async {
    final amount = TextEditingController();
    final notes = TextEditingController();
    DateTime date = DateTime.now();

    try {
      final save = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setLocal) => Padding(
            padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.viewInsetsOf(context).bottom + 20),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Add to ${goal['name'] ?? 'Savings Goal'}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Contribution amount')),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Contribution date'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setLocal(() => date = picked);
                  },
                ),
                TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: () => Navigator.pop(sheetContext, true), icon: const Icon(Icons.add_rounded), label: const Text('Record Contribution')),
              ]),
            ),
          ),
        ),
      );
      if (save != true) return;

      await _service.create('savings-contributions', {
        'savings_goal_id': goal['id'],
        'amount': double.tryParse(amount.text.replaceAll(',', '')) ?? 0,
        'contributed_at': DateFormat('yyyy-MM-dd').format(date),
        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
      });
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      amount.dispose(); notes.dispose();
    }
  }

  Future<void> _goalForm([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final target = TextEditingController(text: existing?['target_amount']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    DateTime? targetDate = DateTime.tryParse(existing?['target_date']?.toString() ?? '');
    String status = existing?['status']?.toString() ?? 'in_progress';
    bool reminder = existing?['reminder_enabled'] == true || existing?['reminder_enabled']?.toString() == '1';
    String channel = existing?['reminder_channel']?.toString() ?? 'email';
    String frequency = existing?['reminder_frequency']?.toString() ?? 'weekly';
    DateTime? nextReminder = DateTime.tryParse(existing?['next_reminder_at']?.toString() ?? '');

    try {
      final save = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: .9,
          minChildSize: .65,
          maxChildSize: .97,
          expand: false,
          builder: (context, controller) => Material(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            color: Theme.of(context).scaffoldBackgroundColor,
            clipBehavior: Clip.antiAlias,
            child: StatefulBuilder(
              builder: (context, setLocal) => ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 28),
                children: [
                  Text(existing == null ? 'Create Savings Goal' : 'Edit Savings Goal', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Goal name *')),
                  const SizedBox(height: 10),
                  TextField(controller: target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target amount *')),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Target date'),
                    subtitle: Text(targetDate == null ? 'Not set' : DateFormat('dd MMM yyyy').format(targetDate!)),
                    trailing: Wrap(children: [
                      if (targetDate != null) IconButton(onPressed: () => setLocal(() => targetDate = null), icon: const Icon(Icons.clear_rounded)),
                      IconButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: targetDate ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(2100));
                          if (picked != null) setLocal(() => targetDate = picked);
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ]),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                      DropdownMenuItem(value: 'paused', child: Text('Paused')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    ],
                    onChanged: (value) => setLocal(() => status = value ?? 'in_progress'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: reminder,
                    title: const Text('Contribution reminders'),
                    subtitle: const Text('Receive a reminder to keep this savings goal moving.'),
                    onChanged: (value) => setLocal(() => reminder = value),
                  ),
                  if (reminder) ...[
                    DropdownButtonFormField<String>(
                      initialValue: channel,
                      decoration: const InputDecoration(labelText: 'Reminder channel'),
                      items: const [
                        DropdownMenuItem(value: 'email', child: Text('Email')),
                        DropdownMenuItem(value: 'sms', child: Text('SMS')),
                        DropdownMenuItem(value: 'both', child: Text('Email + SMS')),
                      ],
                      onChanged: (value) => setLocal(() => channel = value ?? 'email'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'fortnightly', child: Text('Every 2 weeks')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      ],
                      onChanged: (value) => setLocal(() => frequency = value ?? 'weekly'),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Next reminder'),
                      subtitle: Text(nextReminder == null ? 'Not set' : DateFormat('dd MMM yyyy').format(nextReminder!)),
                      trailing: const Icon(Icons.notifications_active_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: nextReminder ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(2100));
                        if (picked != null) setLocal(() => nextReminder = picked);
                      },
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(onPressed: () => Navigator.pop(sheetContext, true), icon: const Icon(Icons.save_outlined), label: Text(existing == null ? 'Create Goal' : 'Save Changes')),
                ],
              ),
            ),
          ),
        ),
      );
      if (save != true) return;

      final body = {
        'name': name.text.trim(),
        'target_amount': double.tryParse(target.text.replaceAll(',', '')) ?? 0,
        'target_date': targetDate == null ? null : DateFormat('yyyy-MM-dd').format(targetDate!),
        'status': status,
        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
        'reminder_enabled': reminder,
        'reminder_channel': channel,
        'reminder_frequency': frequency,
        'next_reminder_at': nextReminder == null ? null : DateFormat('yyyy-MM-dd HH:mm:ss').format(nextReminder!),
      };

      if (existing == null) {
        await _service.create('savings-goals', body);
      } else {
        await _service.update('savings-goals', int.parse(existing['id'].toString()), body);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      name.dispose(); target.dispose(); notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSaved = _goals.fold<double>(0, (sum, e) => sum + _n(e['saved_amount']));
    final totalTarget = _goals.fold<double>(0, (sum, e) => sum + _n(e['target_amount']));

    return Scaffold(
      appBar: AppBar(title: const Text('Savings'), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _goalForm(), icon: const Icon(Icons.add_rounded), label: const Text('New Goal')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _goals.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 220), Center(child: CircularProgressIndicator())])
            : _error != null && _goals.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(24), children: [const SizedBox(height: 120), Text(_error!, textAlign: TextAlign.center)])
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    children: [
                      const Text('Create a target, contribute consistently and see how much remains.',
                          style: TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _SavingMetric('Saved', _money(totalSaved), Icons.savings_outlined)),
                        const SizedBox(width: 8),
                        Expanded(child: _SavingMetric('Remaining', _money((totalTarget - totalSaved).clamp(0, double.infinity)), Icons.flag_outlined)),
                      ]),
                      const SizedBox(height: 12),
                      if (_goals.isEmpty)
                        const Card(child: Padding(padding: EdgeInsets.all(28), child: Column(children: [
                          Icon(Icons.savings_outlined, size: 44),
                          SizedBox(height: 10),
                          Text('No savings goal yet', style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text('Create a goal and record your first contribution.', textAlign: TextAlign.center),
                        ])))
                      else
                        ..._goals.map((goal) {
                          final progress = _n(goal['progress_percent']).clamp(0, 100);
                          final saved = _n(goal['saved_amount']);
                          final target = _n(goal['target_amount']);
                          final remaining = _n(goal['remaining_amount']);
                          final contributions = goal['contributions'] is List ? goal['contributions'] as List : const [];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Row(children: [
                                  Expanded(child: Text((goal['name'] ?? 'Savings Goal').toString(), style: const TextStyle(fontWeight: FontWeight.w900))),
                                  Text('${progress.toStringAsFixed(progress % 1 == 0 ? 0 : 1)}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') _goalForm(goal);
                                      if (value == 'contribute') _addContribution(goal);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'contribute', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.add_card_outlined), title: Text('Add contribution'))),
                                      PopupMenuItem(value: 'edit', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Edit goal'))),
                                    ],
                                  ),
                                ]),
                                Text('${_money(saved)} of ${_money(target)} · ${_money(remaining)} remaining', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                const SizedBox(height: 8),
                                ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: progress / 100, minHeight: 8)),
                                if (contributions.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text('Recent contributions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: contributions.take(5).map((raw) {
                                      final c = raw is Map ? raw : const {};
                                      return Chip(label: Text('${_money(c['amount'])} · ${c['contributed_at'] ?? ''}', style: const TextStyle(fontSize: 10)));
                                    }).toList(growable: false),
                                  ),
                                ],
                              ]),
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}

class _SavingMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SavingMetric(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
        ),
      );
}
