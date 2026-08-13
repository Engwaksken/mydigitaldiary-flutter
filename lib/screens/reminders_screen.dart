import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';

/// Full CRUD example — the pattern to copy for every other module
/// (Meetings, Expenses, Income, Plans, ...): a list with pull-to-refresh,
/// a form bottom sheet shared between create/edit, and swipe-to-delete.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _service = ReminderService();
  List<Reminder> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final reminders = await _service.list();
      await NotificationService.instance.syncReminderSchedules(reminders);
      setState(() {
        _reminders = reminders;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(Reminder reminder) async {
    try {
      await _service.delete(reminder.id);
      await NotificationService.instance.cancelReminder(reminder.id);
      if (!mounted) return;
      setState(() => _reminders.removeWhere((r) => r.id == reminder.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder deleted.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<bool> _confirmDelete(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('Delete “${reminder.title}”? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    return confirmed == true;
  }

  void _openForm({Reminder? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReminderForm(
        existing: existing,
        onSaved: () {
          Navigator.of(context).pop();
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('New Reminder'),
      ),
      body: Column(
        children: [
          if (_reminders.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF00897B).withValues(alpha: 0.06),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, size: 16, color: Color(0xFF00897B)),
                  const SizedBox(width: 8),
                  Text(
                    '${_reminders.length} ${_reminders.length == 1 ? 'reminder' : 'reminders'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF00897B), fontSize: 13),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _reminders.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No reminders yet. Tap + to add one.', textAlign: TextAlign.center),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _reminders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final reminder = _reminders[index];
                      return Dismissible(
                        key: ValueKey(reminder.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          if (await _confirmDelete(reminder)) {
                            await _delete(reminder);
                          }
                          return false;
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: (reminder.isActive ? const Color(0xFF00897B) : Colors.grey).withValues(alpha: 0.12),
                              child: Icon(
                                reminder.isActive ? Icons.notifications_active : Icons.notifications_off,
                                color: reminder.isActive ? const Color(0xFF00897B) : Colors.grey,
                              ),
                            ),
                            title: Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${DateFormat('yMMMd – jm').format(reminder.nextRunAt)} · ${reminder.frequency}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete reminder',
                              onPressed: () async {
                                if (await _confirmDelete(reminder)) await _delete(reminder);
                              },
                            ),
                            onTap: () => _openForm(existing: reminder),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderForm extends StatefulWidget {
  final Reminder? existing;
  final VoidCallback onSaved;

  const _ReminderForm({this.existing, required this.onSaved});

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  final _service = ReminderService();
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  late DateTime _nextRunAt;
  late String _frequency;
  late String _channel;
  String? _module;
  List<Map<String, dynamic>> _moduleItems = [];
  final Set<int> _selectedItemIds = {};
  bool _loadingItems = false;
  bool _saving = false;
  String? _error;

  static const _frequencies = ['once', 'every_n_minutes', 'hourly', 'daily', 'weekly', 'monthly', 'annually'];

  // Matches the "Related Module" options on the web app's own reminder
  // form exactly (see ReminderController::$fields on the Laravel side).
  static const _modules = {
    'daily_planner': 'Daily Planner',
    'income': 'Income',
    'budget': 'Budget',
    'expense': 'Expense',
    'diet': 'Diet',
    'sleep': 'Sleep',
    'health': 'Health Checkup',
    'project': 'Project',
    'meeting': 'Meeting',

    // Personal Life modules. Selecting any of these loads the user's
    // matching records below as checkboxes.
    'education': 'Personal Life — Education',
    'network': 'Personal Life — Network',
    'relationship': 'Personal Life — Relationships',
    'spiritual': 'Personal Life — Spiritual Growth',

    'custom': 'Custom',
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _messageController = TextEditingController(text: widget.existing?.message ?? '');
    _nextRunAt = widget.existing?.nextRunAt ?? DateTime.now().add(const Duration(hours: 1));
    _frequency = widget.existing?.frequency ?? 'once';
    _channel = widget.existing?.channel ?? 'mail';
    _module = widget.existing?.module;
    // If editing a reminder that already has a module, load its items
    // immediately — same as the web app's "load without waiting for a
    // change event that may never fire" behavior for the edit case.
    if (_module != null && _module!.isNotEmpty && _module != 'custom' && _module != 'budget' && _module != 'daily_planner') {
      _loadItemsForModule(_module!);
    }
  }

  Future<void> _loadItemsForModule(String module) async {
    setState(() {
      _loadingItems = true;
      _moduleItems = [];
    });
    try {
      final items = await _service.itemsForModule(module);
      if (mounted) {
        setState(() {
          _moduleItems = items;
          _loadingItems = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextRunAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_nextRunAt));
    if (time == null) return;

    setState(() {
      _nextRunAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final reminder = Reminder(
      id: widget.existing?.id ?? 0,
      title: _titleController.text.trim(),
      module: _module,
      message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
      frequency: _frequency,
      intervalMinutes: widget.existing?.intervalMinutes,
      nextRunAt: _nextRunAt,
      channel: _channel,
      isActive: widget.existing?.isActive ?? true,
      alarmEnabled: widget.existing?.alarmEnabled ?? true,
    );

    try {
      final saved = widget.existing != null
          ? await _service.update(widget.existing!.id, reminder, itemIds: _selectedItemIds.toList())
          : await _service.create(reminder, itemIds: _selectedItemIds.toList());

      // Schedule directly on the phone. Once scheduled, Android/iOS can fire
      // the reminder even when the app is closed or the user is logged out.
      await NotificationService.instance.scheduleReminder(saved);
      widget.onSaved();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing != null ? 'Edit Reminder' : 'New Reminder',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: _messageController, decoration: const InputDecoration(labelText: 'Message (optional)'), maxLines: 2),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Repeats'),
            items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f.replaceAll('_', ' ')))).toList(),
            onChanged: (v) => setState(() => _frequency = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _channel,
            decoration: const InputDecoration(labelText: 'Send Via'),
            items: const [
              DropdownMenuItem(value: 'database', child: Text('In-App Only')),
              DropdownMenuItem(value: 'mail', child: Text('In-App + Email')),
            ],
            onChanged: (v) => setState(() => _channel = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _module,
            decoration: const InputDecoration(
              labelText: 'Related Module (optional)',
              helperText: 'Includes Finance, Health, Work and Personal Life items',
            ),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('None')),
              ..._modules.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
            ],
            onChanged: (v) {
              setState(() {
                _module = v;
                _selectedItemIds.clear();
              });
              if (v != null && v.isNotEmpty && v != 'custom' && v != 'budget') {
                _loadItemsForModule(v);
              } else {
                setState(() => _moduleItems = []);
              }
            },
          ),
          if (_module != null && _module != 'custom' && _module != 'budget' && _module != 'daily_planner') ...[
            const SizedBox(height: 12),
            if (_loadingItems)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_moduleItems.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('No records found in this module yet.', style: TextStyle(color: Colors.grey, fontSize: 12)))
            else ...[
              const Text('Specific item(s) (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const Text(
                'Leave nothing selected to keep this reminder general to the whole module.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView(
                  shrinkWrap: true,
                  children: _moduleItems.map((item) {
                    final id = item['id'] as int;
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['label']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                      value: _selectedItemIds.contains(id),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selectedItemIds.add(id);
                        } else {
                          _selectedItemIds.remove(id);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Next run at'),
            subtitle: Text(DateFormat('yMMMd – jm').format(_nextRunAt)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
