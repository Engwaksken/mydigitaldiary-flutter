import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meeting.dart';
import '../services/meeting_service.dart';
import '../services/api_client.dart';
import 'calendar_sync_sheet.dart';
import 'meeting_detail_screen.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});
  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _service = MeetingService();
  List<Meeting> _meetings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Meeting> _extractMeetings(dynamic result) {
    if (result == null) {
      return <Meeting>[];
    }

    // Older MeetingService versions returned List<Meeting> directly.
    if (result is List<Meeting>) {
      return List<Meeting>.from(result);
    }

    if (result is List) {
      return result.whereType<Meeting>().toList(growable: false);
    }

    // Current installations return a MeetingPage, but the collection getter
    // has changed between mobile revisions. Keep this screen independent of
    // the pagination object's field name so it works with the installed
    // MeetingService without forcing a service/model rewrite.
    dynamic collection;

    for (final getter in <dynamic Function()>[
      () => result.meetings,
      () => result.data,
      () => result.records,
      () => result.results,
      () => result.list,
      () => result.values,
      () => result.items,
    ]) {
      try {
        final value = getter();
        if (value is List) {
          collection = value;
          break;
        }
      } catch (_) {
        // Getter does not exist on this MeetingPage revision.
      }
    }

    if (collection is List) {
      return collection.whereType<Meeting>().toList(growable: false);
    }

    throw StateError(
      'MeetingService returned a MeetingPage whose meeting collection '
      'could not be resolved.',
    );
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final dynamic result = await _service.list();
      final meetings = _extractMeetings(result);

      if (!mounted) return;
      setState(() {
        _meetings = meetings;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openSync() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CalendarSyncSheet(onCompleted: _load),
    );
  }

  Future<void> _delete(Meeting meeting) async {
    try {
      await _service.delete(meeting.id);
      if (mounted) setState(() => _meetings.removeWhere((m) => m.id == meeting.id));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openForm({Meeting? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MeetingForm(
        existing: existing,
        onSaved: () {
          Navigator.of(context).pop();
          _load();
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return const Color(0xFF059669);
      case 'cancelled': return const Color(0xFFE11D48);
      default: return const Color(0xFF00897B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetings'),
        actions: [
          IconButton(
            tooltip: 'Sync Calendar',
            onPressed: _openSync,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _meetings.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 180),
                    Center(child: Text('No meetings yet. Add one or sync your calendar.')),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _meetings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, index) {
                      final meeting = _meetings[index];
                      return Dismissible(
                        key: ValueKey(meeting.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async => await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete meeting?'),
                            content: Text(meeting.title),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        ) ?? false,
                        onDismissed: (_) => _delete(meeting),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(meeting.status).withValues(alpha: .12),
                              child: Icon(Icons.calendar_month, color: _statusColor(meeting.status)),
                            ),
                            title: Row(children: [
                              Expanded(child: Text(meeting.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                              if (meeting.isRecurring || meeting.isGeneratedInstance)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.repeat, size: 16),
                                ),
                            ]),
                            subtitle: Text(
                              '${DateFormat('yMMMd – jm').format(meeting.startAt)}'
                              '${meeting.location != null ? ' · ${meeting.location}' : ''}',
                            ),
                            onTap: () => _openForm(existing: meeting),
                            trailing: IconButton(
                              tooltip: 'Recording, transcript & summary',
                              icon: const Icon(Icons.mic_none),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => MeetingDetailScreen(meeting: meeting)),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _MeetingForm extends StatefulWidget {
  final Meeting? existing;
  final VoidCallback onSaved;
  const _MeetingForm({this.existing, required this.onSaved});

  @override
  State<_MeetingForm> createState() => _MeetingFormState();
}

class _MeetingFormState extends State<_MeetingForm> {
  final _service = MeetingService();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _attendees;
  late final TextEditingController _notes;
  late DateTime _startAt;
  late String _status;
  String? _recurrenceFrequency;
  final Set<int> _recurrenceDays = {};
  DateTime? _recurrenceEndsAt;
  bool _saving = false;
  String? _error;

  static const _weekdayLabels = {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'};

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _title = TextEditingController(text: m?.title ?? '');
    _location = TextEditingController(text: m?.location ?? '');
    _attendees = TextEditingController(text: m?.attendees ?? '');
    _notes = TextEditingController(text: m?.notes ?? '');
    _startAt = m?.startAt ?? DateTime.now().add(const Duration(hours: 1));
    _status = m?.status ?? 'scheduled';
    _recurrenceFrequency = m?.recurrenceFrequency;
    _recurrenceDays.addAll(m?.recurrenceDaysOfWeek ?? const []);
    _recurrenceEndsAt = m?.recurrenceEndsAt;
  }

  @override
  void dispose() {
    _title.dispose(); _location.dispose(); _attendees.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startAt));
    if (t == null) return;
    setState(() => _startAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Meeting title is required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final meeting = Meeting(
      id: widget.existing?.id ?? 0,
      title: _title.text.trim(),
      startAt: _startAt,
      endAt: widget.existing?.endAt,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      attendees: _attendees.text.trim().isEmpty ? null : _attendees.text.trim(),
      status: _status,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      recurrenceFrequency: _recurrenceFrequency,
      recurrenceDaysOfWeek: _recurrenceDays.toList(),
      recurrenceEndsAt: _recurrenceEndsAt,
    );
    try {
      if (widget.existing == null) {
        await _service.create(meeting);
      } else {
        await _service.update(widget.existing!.id, meeting);
      }
      widget.onSaved();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final generated = widget.existing?.isGeneratedInstance ?? false;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'New Meeting' : 'Edit Meeting',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              subtitle: Text(DateFormat('yMMMd – jm').format(_startAt)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickStart,
            ),
            TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location / video link')),
            const SizedBox(height: 10),
            TextField(
              controller: _attendees,
              decoration: const InputDecoration(labelText: 'Attendees', helperText: 'Comma-separated emails'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const ['scheduled','completed','cancelled']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _status = v ?? 'scheduled'),
            ),
            if (!generated) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _recurrenceFrequency,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('Does not repeat')),
                  DropdownMenuItem<String?>(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem<String?>(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem<String?>(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) => setState(() => _recurrenceFrequency = v),
              ),
              if (_recurrenceFrequency == 'weekly') ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _weekdayLabels.entries.map((e) => FilterChip(
                    label: Text(e.value),
                    selected: _recurrenceDays.contains(e.key),
                    onSelected: (selected) => setState(() {
                      selected ? _recurrenceDays.add(e.key) : _recurrenceDays.remove(e.key);
                    }),
                  )).toList(),
                ),
              ],
              if (_recurrenceFrequency != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat until'),
                  subtitle: Text(_recurrenceEndsAt == null ? 'No end date' : DateFormat.yMMMd().format(_recurrenceEndsAt!)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _recurrenceEndsAt ?? _startAt.add(const Duration(days: 30)),
                      firstDate: _startAt,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) setState(() => _recurrenceEndsAt = d);
                  },
                ),
            ],
            TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes / agenda')),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
