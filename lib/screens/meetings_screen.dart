import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meeting.dart';
import '../services/meeting_service.dart';
import '../services/api_client.dart';
import '../widgets/confirm_action_dialog.dart';
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
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  static const int _perPage = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    final requestedPage = page ?? _currentPage;
    setState(() => _loading = true);
    try {
      final result = await _service.list(page: requestedPage, perPage: _perPage);
      if (!mounted) return;
      setState(() {
        _meetings = result.meetings;
        _currentPage = result.currentPage;
        _lastPage = result.lastPage;
        _total = result.total;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  bool _isWebLink(String? value) {
    if (value == null) return false;
    final lower = value.trim().toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
  }

  String _shorten(String value, [int max = 44]) {
    final text = value.trim();
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1)}…';
  }

  List<String> _attendeeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[\s,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _openMeetingLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this meeting link.')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showAttendees(Meeting meeting) async {
    final attendees = _attendeeList(meeting.attendees);
    if (attendees.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attendees List'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: attendees
                  .map((email) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.person_outline, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: SelectableText(email)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showNotes(Meeting meeting) async {
    final notes = meeting.notes?.trim();
    if (notes == null || notes.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notes / Agenda'),
        content: SingleChildScrollView(child: SelectableText(notes)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _delete(Meeting meeting) async {
    try {
      await _service.delete(meeting.id);
      if (!mounted) return;
      setState(() => _meetings.removeWhere((m) => m.id == meeting.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting deleted.')));
      if (_meetings.isEmpty && _currentPage > 1) {
        await _load(page: _currentPage - 1);
      } else {
        await _load(page: _currentPage);
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<bool> _confirmDelete(Meeting meeting) => showAppConfirmDialog(
        context,
        title: 'Delete meeting?',
        message: 'Delete “${meeting.title}”? This action cannot be undone.',
        confirmText: 'Delete meeting',
      );

  void _openForm({Meeting? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
      case 'completed':
        return const Color(0xFF059669);
      case 'cancelled':
        return const Color(0xFFE11D48);
      default:
        return const Color(0xFF00897B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meetings')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_meetings.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF0C3B2E).withValues(alpha: 0.06),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 16, color: Color(0xFF0C3B2E)),
                  const SizedBox(width: 8),
                  Text(
                    '$_total ${_total == 1 ? 'meeting' : 'meetings'} · Page $_currentPage of $_lastPage',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0C3B2E), fontSize: 13),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _meetings.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No meetings yet. Tap + to schedule one.', textAlign: TextAlign.center),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _meetings.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final meeting = _meetings[index];
                      return Dismissible(
                        key: ValueKey(meeting.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          if (await _confirmDelete(meeting)) {
                            await _delete(meeting);
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
                              backgroundColor: _statusColor(meeting.status).withValues(alpha: 0.12),
                              child: Icon(Icons.calendar_month, color: _statusColor(meeting.status)),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(meeting.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                                if (meeting.isRecurring || meeting.isGeneratedInstance)
                                  Tooltip(
                                    message: 'Recurring meeting',
                                    child: Icon(Icons.repeat, size: 16, color: Colors.grey.shade500),
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('yMMMd – jm').format(meeting.startAt)),
                                  if (meeting.location != null && meeting.location!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    if (_isWebLink(meeting.location))
                                      InkWell(
                                        onTap: () => _openMeetingLink(meeting.location!),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.open_in_new, size: 14),
                                            SizedBox(width: 4),
                                            Text('Link', style: TextStyle(fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      )
                                    else
                                      Tooltip(
                                        message: meeting.location!,
                                        child: Text(_shorten(meeting.location!, 38)),
                                      ),
                                  ],
                                  if (_attendeeList(meeting.attendees).isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    InkWell(
                                      onTap: () => _showAttendees(meeting),
                                      child: Text(
                                        'Attendees List (${_attendeeList(meeting.attendees).length})',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (meeting.notes != null && meeting.notes!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    InkWell(
                                      onTap: () => _showNotes(meeting),
                                      child: Tooltip(
                                        message: meeting.notes!,
                                        child: Text('Notes: ${_shorten(meeting.notes!, 42)}'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.mic_none),
                                  tooltip: 'Recording, transcript & summary',
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => MeetingDetailScreen(meeting: meeting)),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Delete meeting',
                                  onPressed: () async {
                                    if (await _confirmDelete(meeting)) await _delete(meeting);
                                  },
                                ),
                              ],
                            ),
                            onTap: () => _openForm(existing: meeting),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
          if (!_loading && _lastPage > 1)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentPage > 1 ? () => _load(page: _currentPage - 1) : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Previous'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('$_currentPage / $_lastPage', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentPage < _lastPage ? () => _load(page: _currentPage + 1) : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Next'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _attendeesController;
  late final TextEditingController _notesController;
  late DateTime _startAt;
  late String _status;
  String? _recurrenceFrequency; // null = "does not repeat"
  final Set<int> _recurrenceDaysOfWeek = {};
  DateTime? _recurrenceEndsAt;
  bool _saving = false;
  String? _error;

  static const _statuses = ['scheduled', 'completed', 'cancelled'];
  static const _weekdayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _locationController = TextEditingController(text: widget.existing?.location ?? '');
    _attendeesController = TextEditingController(text: widget.existing?.attendees ?? '');
    _notesController = TextEditingController(text: widget.existing?.notes ?? '');
    _startAt = widget.existing?.startAt ?? DateTime.now().add(const Duration(hours: 1));
    _status = widget.existing?.status ?? 'scheduled';
    _recurrenceFrequency = widget.existing?.recurrenceFrequency;
    _recurrenceDaysOfWeek.addAll(widget.existing?.recurrenceDaysOfWeek ?? []);
    _recurrenceEndsAt = widget.existing?.recurrenceEndsAt;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startAt));
    if (time == null) return;

    setState(() {
      _startAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final meeting = Meeting(
      id: widget.existing?.id ?? 0,
      title: _titleController.text.trim(),
      startAt: _startAt,
      endAt: widget.existing?.endAt,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      attendees: _attendeesController.text.trim().isEmpty ? null : _attendeesController.text.trim(),
      status: _status,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      recurrenceFrequency: _recurrenceFrequency,
      recurrenceDaysOfWeek: _recurrenceDaysOfWeek.toList(),
      recurrenceEndsAt: _recurrenceEndsAt,
    );

    try {
      if (widget.existing != null) {
        await _service.update(widget.existing!.id, meeting);
      } else {
        await _service.create(meeting);
      }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing != null ? 'Edit Meeting' : 'New Meeting',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              subtitle: Text(DateFormat('yMMMd – jm').format(_startAt)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDateTime,
            ),
            TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location / video link (optional)')),
            const SizedBox(height: 12),
            TextField(
              controller: _attendeesController,
              decoration: const InputDecoration(
                labelText: 'Attendees (optional)',
                helperText: 'Comma-separated emails',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            if (widget.existing == null || !widget.existing!.isGeneratedInstance) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _recurrenceFrequency,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Does not repeat')),
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) => setState(() => _recurrenceFrequency = v),
              ),
              if (_recurrenceFrequency == 'weekly') ...[
                const SizedBox(height: 10),
                const Text('Repeat on', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: _weekdayLabels.entries.map((entry) {
                    final selected = _recurrenceDaysOfWeek.contains(entry.key);
                    return FilterChip(
                      label: Text(entry.value),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _recurrenceDaysOfWeek.add(entry.key);
                        } else {
                          _recurrenceDaysOfWeek.remove(entry.key);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const Text(
                  'Leave none selected to repeat on the same weekday as the Start date/time above.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
              if (_recurrenceFrequency != null) ...[
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat until (optional)'),
                  subtitle: Text(_recurrenceEndsAt == null ? 'No end date' : DateFormat('yMMMd').format(_recurrenceEndsAt!)),
                  trailing: _recurrenceEndsAt != null
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _recurrenceEndsAt = null))
                      : const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _recurrenceEndsAt ?? _startAt.add(const Duration(days: 30)),
                      firstDate: _startAt,
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) setState(() => _recurrenceEndsAt = picked);
                  },
                ),
              ],
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes / agenda (optional)'),
              maxLines: 3,
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
      ),
    );
  }
}
