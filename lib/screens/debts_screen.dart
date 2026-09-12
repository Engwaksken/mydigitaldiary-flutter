import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/personal_management_service.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final _service = const PersonalManagementService();
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final rows = await _service.list('debts');
      if (!mounted) return;
      setState(() { _items = rows; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load debts.'; });
    }
  }

  double _amount(Map<String, dynamic> item) =>
      double.tryParse((item['amount'] ?? '0').toString().replaceAll(',', '')) ?? 0;

  String _money(double value) =>
      NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(value);

  Future<void> _sendReminder(Map<String, dynamic> debt) async {
    String channel = (debt['reminder_channel'] ?? 'email').toString();
    if (!['email','sms','both'].contains(channel)) channel = 'email';
    String scope = 'counterparty';
    final message = TextEditingController();

    try {
      final send = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setLocal) => Padding(
            padding: EdgeInsets.fromLTRB(
              18, 4, 18, MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Send Debt Reminder',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    '${debt['person_name'] ?? 'Borrower / lender'} · ${_money(_amount(debt))}',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: channel,
                    decoration: const InputDecoration(labelText: 'Channel'),
                    items: const [
                      DropdownMenuItem(value: 'email', child: Text('Email only')),
                      DropdownMenuItem(value: 'sms', child: Text('SMS only')),
                      DropdownMenuItem(value: 'both', child: Text('Email + SMS')),
                    ],
                    onChanged: (value) => setLocal(() => channel = value ?? 'email'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: scope,
                    decoration: const InputDecoration(labelText: 'Send to'),
                    items: const [
                      DropdownMenuItem(value: 'counterparty', child: Text('Borrower / lender')),
                      DropdownMenuItem(value: 'me', child: Text('Me')),
                      DropdownMenuItem(value: 'both', child: Text('Both')),
                    ],
                    onChanged: (value) => setLocal(() => scope = value ?? 'counterparty'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: message,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Custom message (optional)',
                      hintText: 'Leave blank to use the standard reminder wording.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send Reminder'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (send != true) return;

      await _service.sendDebtReminder(
        int.parse(debt['id'].toString()),
        channel: channel,
        recipientScope: scope,
        message: message.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debt reminder processed.')),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      message.dispose();
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final person = TextEditingController(text: existing?['person_name']?.toString() ?? '');
    final email = TextEditingController(text: existing?['contact_email']?.toString() ?? '');
    final phone = TextEditingController(text: existing?['contact_phone']?.toString() ?? '');
    final amount = TextEditingController(text: existing?['amount']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    String type = existing?['type']?.toString() ?? 'lent';
    String status = existing?['status']?.toString() ?? 'outstanding';
    String channel = existing?['reminder_channel']?.toString() ?? 'email';
    String frequency = existing?['reminder_frequency']?.toString() ?? 'weekly';
    bool automatic = existing?['reminder_enabled'] == true ||
        existing?['reminder_enabled']?.toString() == '1';
    DateTime date = DateTime.tryParse(existing?['date']?.toString() ?? '') ?? DateTime.now();
    DateTime? due = DateTime.tryParse(existing?['due_date']?.toString() ?? '');
    DateTime? nextReminder = DateTime.tryParse(existing?['next_reminder_at']?.toString() ?? '');

    try {
      final save = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
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
              builder: (context, setLocal) => ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 28,
                ),
                children: [
                  Text(existing == null ? 'Add Debt' : 'Edit Debt',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'borrowed', child: Text('Borrowed — I owe them')),
                      DropdownMenuItem(value: 'lent', child: Text('Lent — they owe me')),
                    ],
                    onChanged: (value) => setLocal(() => type = value ?? 'lent'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: person, decoration: const InputDecoration(labelText: 'Borrower / lender *')),
                  const SizedBox(height: 10),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 10),
                  TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone / SMS number')),
                  const SizedBox(height: 10),
                  TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Outstanding amount *')),
                  const SizedBox(height: 10),
                  _DateTile(label: 'Debt date', date: date, onPick: () async {
                    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setLocal(() => date = picked);
                  }),
                  _DateTile(label: 'Due date', date: due, optional: true, onPick: () async {
                    final picked = await showDatePicker(context: context, initialDate: due ?? date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setLocal(() => due = picked);
                  }, onClear: () => setLocal(() => due = null)),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'outstanding', child: Text('Outstanding')),
                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    ],
                    onChanged: (value) => setLocal(() => status = value ?? 'outstanding'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes')),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Automatic reminders'),
                    subtitle: const Text('Send scheduled reminders using the selected channel.'),
                    value: automatic,
                    onChanged: (value) => setLocal(() => automatic = value),
                  ),
                  if (automatic) ...[
                    DropdownButtonFormField<String>(
                      initialValue: channel,
                      decoration: const InputDecoration(labelText: 'Reminder channel'),
                      items: const [
                        DropdownMenuItem(value: 'email', child: Text('Email only')),
                        DropdownMenuItem(value: 'sms', child: Text('SMS only')),
                        DropdownMenuItem(value: 'both', child: Text('Email + SMS')),
                      ],
                      onChanged: (value) => setLocal(() => channel = value ?? 'email'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(value: 'once', child: Text('Once')),
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'every_3_days', child: Text('Every 3 days')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'fortnightly', child: Text('Every 2 weeks')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      ],
                      onChanged: (value) => setLocal(() => frequency = value ?? 'weekly'),
                    ),
                    const SizedBox(height: 8),
                    _DateTile(label: 'Next reminder date', date: nextReminder, optional: true, onPick: () async {
                      final picked = await showDatePicker(context: context, initialDate: nextReminder ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(2100));
                      if (picked != null) setLocal(() => nextReminder = picked);
                    }),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(existing == null ? 'Add Debt' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (save != true) return;

      final body = <String, dynamic>{
        'type': type,
        'person_name': person.text.trim(),
        'contact_email': email.text.trim().isEmpty ? null : email.text.trim(),
        'contact_phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
        'amount': double.tryParse(amount.text.replaceAll(',', '')) ?? 0,
        'date': DateFormat('yyyy-MM-dd').format(date),
        'due_date': due == null ? null : DateFormat('yyyy-MM-dd').format(due!),
        'status': status,
        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
        'reminder_enabled': automatic,
        'reminder_channel': channel,
        'reminder_frequency': frequency,
        'next_reminder_at': nextReminder == null ? null : DateFormat('yyyy-MM-dd HH:mm:ss').format(nextReminder!),
      };

      if (existing == null) {
        await _service.create('debts', body);
      } else {
        await _service.update('debts', int.parse(existing['id'].toString()), body);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      person.dispose(); email.dispose(); phone.dispose(); amount.dispose(); notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = _items.where((e) => (e['status'] ?? '') == 'outstanding').toList();
    final borrowed = outstanding.where((e) => (e['type'] ?? '') == 'borrowed').fold<double>(0, (sum, e) => sum + _amount(e));
    final lent = outstanding.where((e) => (e['type'] ?? '') == 'lent').fold<double>(0, (sum, e) => sum + _amount(e));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Debt'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _items.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 220), Center(child: CircularProgressIndicator())])
            : _error != null && _items.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(24), children: [const SizedBox(height: 120), Text(_error!, textAlign: TextAlign.center)])
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    children: [
                      const Text('Track what you owe and what is owed to you, then follow up before commitments are forgotten.',
                          style: TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _SummaryCard(label: 'I owe', value: _money(borrowed), icon: Icons.south_east_rounded)),
                        const SizedBox(width: 8),
                        Expanded(child: _SummaryCard(label: 'Owed to me', value: _money(lent), icon: Icons.north_east_rounded)),
                      ]),
                      const SizedBox(height: 12),
                      if (_items.isEmpty)
                        const _EmptyCard(
                          icon: Icons.handshake_outlined,
                          title: 'No debts recorded',
                          message: 'Add a borrowed or lent amount to start tracking due dates and reminders.',
                        )
                      else
                        ..._items.map((debt) => Card(
                              child: ListTile(
                                onTap: () => _openForm(debt),
                                leading: CircleAvatar(
                                  child: Icon((debt['type'] ?? '') == 'lent' ? Icons.call_received_rounded : Icons.call_made_rounded),
                                ),
                                title: Text((debt['person_name'] ?? 'Debt').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text(
                                  '${_money(_amount(debt))} · ${(debt['status'] ?? 'outstanding').toString()}'
                                  '${debt['due_date'] != null ? ' · due ${debt['due_date']}' : ''}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'remind') _sendReminder(debt);
                                    if (value == 'edit') _openForm(debt);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'remind', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.notifications_active_outlined), title: Text('Send reminder'))),
                                    PopupMenuItem(value: 'edit', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool optional;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  const _DateTile({required this.label, required this.date, required this.onPick, this.optional = false, this.onClear});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(date == null ? (optional ? 'Not set' : 'Choose date') : DateFormat('dd MMM yyyy').format(date!)),
        trailing: Wrap(children: [
          if (date != null && onClear != null) IconButton(onPressed: onClear, icon: const Icon(Icons.clear_rounded)),
          IconButton(onPressed: onPick, icon: const Icon(Icons.calendar_month_outlined)),
        ]),
      );
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryCard({required this.label, required this.value, required this.icon});
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

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyCard({required this.icon, required this.title, required this.message});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(icon, size: 42),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
          ]),
        ),
      );
}
