import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/calendar_sync_result.dart';
import '../services/api_client.dart';
import '../services/meeting_calendar_sync_service.dart';

class CalendarSyncSheet extends StatefulWidget {
  final VoidCallback onCompleted;

  const CalendarSyncSheet({
    super.key,
    required this.onCompleted,
  });

  @override
  State<CalendarSyncSheet> createState() => _CalendarSyncSheetState();
}

class _CalendarSyncSheetState extends State<CalendarSyncSheet> {
  final MeetingCalendarSyncService _service =
      const MeetingCalendarSyncService();

  String _provider = 'all';
  late DateTime _from;
  late DateTime _to;

  bool _includeRecurring = true;
  bool _loading = false;
  CalendarSyncResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _pickFrom() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date == null) return;

    setState(() {
      _from = date;
      if (_to.isBefore(_from)) {
        _to = _from;
      }
    });
  }

  Future<void> _pickTo() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date == null) return;

    setState(() => _to = date);
  }

  void _quickRange(String range) {
    final now = DateTime.now();

    setState(() {
      switch (range) {
        case 'today':
          _from = DateTime(now.year, now.month, now.day);
          _to = _from;
          break;
        case '7':
          _from = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6));
          _to = DateTime(now.year, now.month, now.day);
          break;
        case '30':
          _from = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 29));
          _to = DateTime(now.year, now.month, now.day);
          break;
        case 'month':
          _from = DateTime(now.year, now.month, 1);
          _to = DateTime(now.year, now.month + 1, 0);
          break;
      }
    });
  }

  Future<void> _sync() async {
    if (_to.isBefore(_from)) {
      setState(() {
        _error = 'The sync-to date cannot be before the sync-from date.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await _service.sync(
        provider: _provider == 'all' ? null : _provider,
        from: _from,
        to: _to,
        includeRecurring: _includeRecurring,
      );

      if (!mounted) return;

      setState(() => _result = result);
      widget.onCompleted();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Calendar sync could not be completed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.sync_alt_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync selected dates',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const Text(
                          'Choose the exact period to import from your authorised calendars.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _provider,
                decoration: const InputDecoration(
                  labelText: 'Calendar / provider',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All connected calendars'),
                  ),
                  DropdownMenuItem(
                    value: 'google',
                    child: Text('Google Calendar'),
                  ),
                  DropdownMenuItem(
                    value: 'microsoft',
                    child: Text('Microsoft Outlook / Teams'),
                  ),
                  DropdownMenuItem(
                    value: 'zoom',
                    child: Text('Zoom'),
                  ),
                  DropdownMenuItem(
                    value: 'webex',
                    child: Text('Webex'),
                  ),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _provider = value ?? 'all');
                      },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Today'),
                    onPressed: _loading ? null : () => _quickRange('today'),
                  ),
                  ActionChip(
                    label: const Text('Last 7 days'),
                    onPressed: _loading ? null : () => _quickRange('7'),
                  ),
                  ActionChip(
                    label: const Text('Last 30 days'),
                    onPressed: _loading ? null : () => _quickRange('30'),
                  ),
                  ActionChip(
                    label: const Text('This month'),
                    onPressed: _loading ? null : () => _quickRange('month'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DateBox(
                      label: 'Sync from',
                      value: df.format(_from),
                      icon: Icons.event_available_outlined,
                      onTap: _loading ? null : _pickFrom,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateBox(
                      label: 'Sync to',
                      value: df.format(_to),
                      icon: Icons.event_outlined,
                      onTap: _loading ? null : _pickTo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _includeRecurring,
                title: const Text('Include recurring events'),
                subtitle: const Text(
                  'Only occurrences within the selected period are imported.',
                ),
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _includeRecurring = value);
                      },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFBE123C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Calendar sync completed',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Imported ${_result!.imported} · '
                        'Updated ${_result!.updated} · '
                        'Skipped ${_result!.skipped} · '
                        'Failed ${_result!.failed}',
                      ),
                      if (_result!.errors.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _result!.errors.join('\n'),
                          style: const TextStyle(
                            color: Color(0xFFBE123C),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loading ? null : _sync,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  _loading ? 'Syncing selected dates…' : 'Sync selected dates',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _DateBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
