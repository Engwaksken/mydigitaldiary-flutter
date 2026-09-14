import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Meeting> _meetings = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  int _total = 0;
  String _searchQuery = '';
  String? _statusFilter;

  static const _perPage = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final page = await _service.list(
        page: 1,
        perPage: _perPage,
        search: _searchQuery,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _meetings = page.meetings;
        _page = page.currentPage;
        _hasMore = page.currentPage < page.lastPage;
        _total = page.total;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.list(
        page: _page + 1,
        perPage: _perPage,
        search: _searchQuery,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _meetings = [..._meetings, ...page.meetings];
        _page = page.currentPage;
        _hasMore = page.currentPage < page.lastPage;
        _total = page.total;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _onSearchChanged(String value) {
    setState(() {}); // rebuild to show/hide the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
      _load();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
    _load();
  }

  void _setStatusFilter(String? status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _load();
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
      if (mounted)
        setState(() => _meetings.removeWhere((m) => m.id == meeting.id));
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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

  Future<void> _joinMeeting(Meeting meeting) async {
    if (meeting.diaryJoinUrl == null) return;
    final uri = Uri.parse(meeting.diaryJoinUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openLocation(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  bool _isUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
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

  // ── Computed stats for internal meetings ──
  List<Meeting> get _internalMeetings =>
      _meetings.where((m) => m.diaryJoinUrl != null).toList();

  int get _totalCount => _internalMeetings.length;

  int get _upcomingCount => _internalMeetings
      .where((m) =>
          m.status == 'scheduled' && m.startAt.isAfter(DateTime.now()))
      .length;

  int get _completedCount =>
      _internalMeetings.where((m) => m.status == 'completed').length;

  int get _attendeeCount => _internalMeetings
      .expand((m) => (m.attendees ?? '')
          .split(RegExp(r'[,;\s]+'))
          .where((e) => e.trim().isNotEmpty))
      .toSet()
      .length;

  // ── Stats card widget ──
  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  // ── Status filter chip ──
  Widget _filterChip(String label, String? value) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _setStatusFilter(value),
      ),
    );
  }

  // ── Location: plain text, or an "Open Link" chip when it's a URL ──
  Widget _locationWidget(Meeting meeting) {
    final location = meeting.location;
    if (location == null || location.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    if (!_isUrl(location)) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          location,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ActionChip(
        avatar: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Open Link'),
        visualDensity: VisualDensity.compact,
        onPressed: () => _openLocation(location),
      ),
    );
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
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // ── Search bar ──
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search meetings…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Status filter chips ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('All', null),
                        _filterChip('Scheduled', 'scheduled'),
                        _filterChip('Completed', 'completed'),
                        _filterChip('Cancelled', 'cancelled'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Internal meetings stats cards ──
                  if (_internalMeetings.isNotEmpty) ...[
                    Text('Internal Meetings',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _statCard('Total', '$_totalCount',
                              Icons.calendar_today, const Color(0xFF6366F1)),
                          _statCard('Upcoming', '$_upcomingCount',
                              Icons.event, const Color(0xFF0EA5E9)),
                          _statCard('Completed', '$_completedCount',
                              Icons.check_circle, const Color(0xFF059669)),
                          _statCard('Attendees', '$_attendeeCount',
                              Icons.people, const Color(0xFF3B82F6)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // ── Empty state ──
                  if (_meetings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: Text(
                          _searchQuery.isNotEmpty || _statusFilter != null
                              ? 'No meetings match your search.'
                              : 'No meetings yet. Add one or sync your calendar.',
                        ),
                      ),
                    )
                  else ...[
                    // ── Meeting list ──
                    ...List.generate(_meetings.length, (index) {
                      final meeting = _meetings[index];
                      return Dismissible(
                        key: ValueKey(meeting.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async =>
                            await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete meeting?'),
                                content: Text(meeting.title),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete')),
                                ],
                              ),
                            ) ??
                            false,
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
                              backgroundColor: _statusColor(meeting.status)
                                  .withValues(alpha: .12),
                              child: Icon(Icons.calendar_month,
                                  color: _statusColor(meeting.status)),
                            ),
                            title: Row(children: [
                              Expanded(
                                  child: Text(meeting.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700))),
                              if (meeting.isRecurring ||
                                  meeting.isGeneratedInstance)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.repeat, size: 16),
                                ),
                            ]),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('yMMMd – jm')
                                    .format(meeting.startAt)),
                                _locationWidget(meeting),
                              ],
                            ),
                            onTap: () => _openForm(existing: meeting),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (meeting.diaryJoinUrl != null)
                                  IconButton(
                                    tooltip: 'Join meeting',
                                    icon: const Icon(Icons.launch,
                                        color: Color(0xFF059669)),
                                    onPressed: () =>
                                        _joinMeeting(meeting),
                                  ),
                                IconButton(
                                  tooltip:
                                      'Recording, transcript & summary',
                                  icon: const Icon(Icons.mic_none),
                                  onPressed: () =>
                                      Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            MeetingDetailScreen(
                                                meeting: meeting)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    // ── Load more ──
                    if (_hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _loadingMore
                            ? const Center(
                                child: CircularProgressIndicator())
                            : OutlinedButton.icon(
                                onPressed: _loadMore,
                                icon: const Icon(Icons.expand_more),
                                label: const Text('Load more'),
                              ),
                      ),
                    if (!_hasMore && _meetings.length > _perPage)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            'Showing all $_total meetings',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
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

  static const _weekdayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun'
  };

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
    _title.dispose();
    _location.dispose();
    _attendees.dispose();
    _notes.dispose();
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
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_startAt));
    if (t == null) return;
    setState(
        () => _startAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Meeting title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final meeting = Meeting(
      id: widget.existing?.id ?? 0,
      title: _title.text.trim(),
      startAt: _startAt,
      endAt: widget.existing?.endAt,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      attendees:
          _attendees.text.trim().isEmpty ? null : _attendees.text.trim(),
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
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'New Meeting' : 'Edit Meeting',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              subtitle: Text(DateFormat('yMMMd – jm').format(_startAt)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickStart,
            ),
            TextField(
                controller: _location,
                decoration: const InputDecoration(
                    labelText: 'Location / video link')),
            const SizedBox(height: 10),
            TextField(
              controller: _attendees,
              decoration: const InputDecoration(
                  labelText: 'Attendees',
                  helperText: 'Comma-separated emails'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const ['scheduled', 'completed', 'cancelled']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _status = v ?? 'scheduled'),
            ),
            if (!generated) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _recurrenceFrequency,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: const [
                  DropdownMenuItem<String?>(
                      value: null, child: Text('Does not repeat')),
                  DropdownMenuItem<String?>(
                      value: 'daily', child: Text('Daily')),
                  DropdownMenuItem<String?>(
                      value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem<String?>(
                      value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) =>
                    setState(() => _recurrenceFrequency = v),
              ),
              if (_recurrenceFrequency == 'weekly') ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _weekdayLabels.entries
                      .map((e) => FilterChip(
                            label: Text(e.value),
                            selected: _recurrenceDays.contains(e.key),
                            onSelected: (selected) => setState(() {
                              selected
                                  ? _recurrenceDays.add(e.key)
                                  : _recurrenceDays.remove(e.key);
                            }),
                          ))
                      .toList(),
                ),
              ],
              if (_recurrenceFrequency != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat until'),
                  subtitle: Text(_recurrenceEndsAt == null
                      ? 'No end date'
                      : DateFormat.yMMMd().format(_recurrenceEndsAt!)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _recurrenceEndsAt ??
                          _startAt.add(const Duration(days: 30)),
                      firstDate: _startAt,
                      lastDate: DateTime.now()
                          .add(const Duration(days: 3650)),
                    );
                    if (d != null) setState(() => _recurrenceEndsAt = d);
                  },
                ),
            ],
            TextField(
                controller: _notes,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Notes / agenda')),
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