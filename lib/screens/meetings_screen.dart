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
  String _period = 'day'; // day | week | month

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
      var cursor = await _service.list(
        page: 1,
        perPage: _perPage,
        search: _searchQuery,
        status: _statusFilter,
        period: _period,
      );
      var meetings = cursor.meetings;
      // Pull in every page so Day / Week / Month views have the full set,
      // not just the most recent page worth of meetings.
      var guard = 0;
      while (cursor.currentPage < cursor.lastPage && guard < 10) {
        guard++;
        cursor = await _service.list(
          page: cursor.currentPage + 1,
          perPage: _perPage,
          search: _searchQuery,
          status: _statusFilter,
          period: _period,
        );
        meetings = [...meetings, ...cursor.meetings];
      }
      if (!mounted) return;
      setState(() {
        _meetings = List<Meeting>.from(meetings)
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
        _page = cursor.currentPage;
        _hasMore = cursor.currentPage < cursor.lastPage;
        _total = cursor.total;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
        period: _period,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
      if (mounted) {
        setState(() => _meetings.removeWhere((m) => m.id == meeting.id));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
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

  Future<void> _openLocation(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
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

  // Meetings falling inside the currently selected Day / Week / Month window.
  List<Meeting> get _visibleMeetings {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime from;
    DateTime to;
    switch (_period) {
      case 'week':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        from = monday;
        to = monday.add(const Duration(days: 7));
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 1);
        break;
      default:
        from = today;
        to = today.add(const Duration(days: 1));
    }
    return _meetings
        .where((m) {
          final start = m.startAt;
          return !start.isBefore(from) && start.isBefore(to);
        })
        .toList(growable: false);
  }

  String get _periodLabel {
    switch (_period) {
      case 'week':
        return 'this week';
      case 'month':
        return 'this month';
      default:
        return 'today';
    }
  }

  List<Meeting> get _internalMeetings =>
      _visibleMeetings.where((m) => m.diaryJoinUrl != null).toList();

  int get _totalCount => _internalMeetings.length;

  int get _upcomingCount => _internalMeetings
      .where(
        (m) => m.status == 'scheduled' && m.startAt.isAfter(DateTime.now()),
      )
      .length;

  int get _completedCount =>
      _internalMeetings.where((m) => m.status == 'completed').length;

  int get _attendeeCount => _internalMeetings
      .expand(
        (m) => (m.attendees ?? '')
            .split(RegExp(r'[,;\s]+'))
            .where((e) => e.trim().isNotEmpty),
      )
      .toSet()
      .length;

  // ── Stats card widget ──
  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 112,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
          ),
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
                  // ── Day / Week / Month period picker ──
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'day',
                        label: Text('Day'),
                        icon: Icon(Icons.today_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: 'week',
                        label: Text('Week'),
                        icon: Icon(Icons.view_week_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: 'month',
                        label: Text('Month'),
                        icon: Icon(Icons.calendar_month_outlined, size: 18),
                      ),
                    ],
                    selected: {_period},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() => _period = selection.first);
                      _load();
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                    Text(
                      'Internal Meetings · $_periodLabel',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 92,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _statCard(
                            'Total',
                            '$_totalCount',
                            Icons.calendar_today,
                            const Color(0xFF6366F1),
                          ),
                          _statCard(
                            'Upcoming',
                            '$_upcomingCount',
                            Icons.event,
                            const Color(0xFF0EA5E9),
                          ),
                          _statCard(
                            'Completed',
                            '$_completedCount',
                            Icons.check_circle,
                            const Color(0xFF059669),
                          ),
                          _statCard(
                            'Attendees',
                            '$_attendeeCount',
                            Icons.people,
                            const Color(0xFF3B82F6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // ── Empty state ──
                  if (_visibleMeetings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.event_busy_outlined,
                              size: 42,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _searchQuery.isNotEmpty || _statusFilter != null
                                  ? 'No meetings match your search.'
                                  : _meetings.isEmpty
                                  ? 'No meetings yet. Add one or sync your calendar.'
                                  : 'No meetings $_periodLabel. Switch to Week or Month to see more.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // ── Meeting list ──
                    ...List.generate(_visibleMeetings.length, (index) {
                      final meeting = _visibleMeetings[index];
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
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
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
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(
                                meeting.status,
                              ).withValues(alpha: .12),
                              child: Icon(
                                Icons.calendar_month,
                                color: _statusColor(meeting.status),
                              ),
                            ),
                            title: Text(
                              meeting.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat(
                                    'yMMMd – jm',
                                  ).format(meeting.startAt),
                                ),
                                _locationWidget(meeting),
                              ],
                            ),
                            onTap: () => _openForm(existing: meeting),
                            trailing: IconButton(
                              tooltip: 'View meeting',
                              icon: const Icon(Icons.visibility_outlined),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MeetingDetailScreen(meeting: meeting),
                                ),
                              ),
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
                            ? const Center(child: CircularProgressIndicator())
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
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
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
    7: 'Sun',
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
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (t == null) return;
    setState(
      () => _startAt = DateTime(d.year, d.month, d.day, t.hour, t.minute),
    );
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
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'New Meeting' : 'Edit Meeting',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
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
                labelText: 'Location / video link',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _attendees,
              decoration: const InputDecoration(
                labelText: 'Attendees',
                helperText: 'Comma-separated emails',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                'scheduled',
                'completed',
                'cancelled',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _status = v ?? 'scheduled'),
            ),
            if (!generated) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _recurrenceFrequency,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Does not repeat'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'daily',
                    child: Text('Daily'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'weekly',
                    child: Text('Weekly'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'monthly',
                    child: Text('Monthly'),
                  ),
                ],
                onChanged: (v) => setState(() => _recurrenceFrequency = v),
              ),
              if (_recurrenceFrequency == 'weekly') ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _weekdayLabels.entries
                      .map(
                        (e) => FilterChip(
                          label: Text(e.value),
                          selected: _recurrenceDays.contains(e.key),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _recurrenceDays.add(e.key)
                                : _recurrenceDays.remove(e.key);
                          }),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (_recurrenceFrequency != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat until'),
                  subtitle: Text(
                    _recurrenceEndsAt == null
                        ? 'No end date'
                        : DateFormat.yMMMd().format(_recurrenceEndsAt!),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate:
                          _recurrenceEndsAt ??
                          _startAt.add(const Duration(days: 30)),
                      firstDate: _startAt,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) setState(() => _recurrenceEndsAt = d);
                  },
                ),
            ],
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes / agenda'),
            ),
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
