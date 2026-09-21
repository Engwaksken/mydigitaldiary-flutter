import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../services/meeting_calendar_sync_service.dart';
import '../services/pending_recording_sync_service.dart';
import '../services/sync_status_service.dart';
import '../services/offline_mutation_queue.dart';

/// Wraps the rest of the app. Previously this fully blocked the UI
/// whenever offline — reconsidered after realizing that's actively
/// harmful for exactly the situation it was meant to help with:
/// someone in a low/no-connectivity area still needs to SEE whatever
/// data is already cached on their device (see ApiClient's cacheable
/// GET support), not be shown a wall instead. Now it's a dismissible
/// banner overlaid on top of the normal app content — informs without
/// blocking.
///
/// NOTE: connectivity_plus's exact API shape has changed across major
/// versions — v6.x (declared in pubspec.yaml) returns a
/// List<ConnectivityResult> from both checkConnectivity() and the
/// onConnectivityChanged stream, which is what this assumes below. If
/// this doesn't compile against whatever version actually resolves,
/// the fix is almost certainly changing List<ConnectivityResult> to a
/// bare ConnectivityResult (older versions' shape) or vice versa.
class ConnectivityGate extends StatefulWidget {
  final Widget child;

  const ConnectivityGate({super.key, required this.child});

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isConnected = true;
  bool _dismissed = false;
  bool _showSyncedBanner = false;
  int _pendingUploads = 0;
  int _pendingChanges = 0;
  int _conflicts = 0;
  Timer? _syncedTimer;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _subscription = _connectivity.onConnectivityChanged.listen(_handleResult);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _syncedTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitial() async {
    // Connectivity state is advisory only and must never delay the app. Some
    // Android devices take surprisingly long to answer this call while radios
    // are waking up, so give it a very small budget and assume online until a
    // real stream event says otherwise.
    List<ConnectivityResult> result;
    try {
      result = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(milliseconds: 700));
    } on TimeoutException {
      return;
    } catch (_) {
      return;
    }
    _handleResult(result);
    // Separate from the transition-detection in _handleResult below —
    // that only fires on an OFFLINE-to-ONLINE change, which wouldn't
    // catch the case of the app launching already online with
    // recordings queued from a previous offline session. Always worth
    // attempting once at startup regardless of prior state.
    if (result.any((r) => r != ConnectivityResult.none)) {
      _syncAfterReconnect();
    }
  }

  void _handleResult(List<ConnectivityResult> result) {
    final connected = result.any((r) => r != ConnectivityResult.none);
    final wasOffline = !_isConnected;
    if (mounted) {
      setState(() {
        _isConnected = connected;
        // Reset dismissal once back online, so a LATER disconnect
        // shows the banner again rather than staying silently hidden
        // forever after the first dismissal.
        if (connected) _dismissed = false;
      });
    }
    if (connected && wasOffline) {
      // Fire-and-forget — any meeting detail screen currently open
      // reloads its own pending list via its own _load(), this just
      // needs to actually attempt the uploads.
      _syncAfterReconnect();
    }
  }

  Future<void> _syncAfterReconnect() async {
    try {
      await OfflineMutationQueue.instance.syncAll();
      await PendingRecordingSyncService().syncAll();
      final snapshot = await SyncStatusService().refresh();
      if (!mounted) return;
      setState(() {
        _pendingUploads = snapshot.pendingUploads;
        _pendingChanges = snapshot.pendingChanges;
        _conflicts = snapshot.conflicts;
        _showSyncedBanner = true;
      });
      _syncedTimer?.cancel();
      _syncedTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showSyncedBanner = false);
      });
    } catch (_) {
      // Connectivity is advisory; failed sync will be attempted again on the
      // next reconnect/app launch without blocking the user.
    }

    await _promptPendingCalendarSync();
  }

  /// If a calendar-sync with selected dates was interrupted while offline,
  /// offer to run it again now that we're back online. Confirmed by the
  /// user rather than run automatically, so nothing is synced behind their
  /// back.
  Future<void> _promptPendingCalendarSync() async {
    if (!mounted) return;

    const service = MeetingCalendarSyncService();
    if (!await service.hasPending()) return;

    final selection = await service.lastSelection();
    final from = selection?['from'] as DateTime?;
    final to = selection?['to'] as DateTime?;
    if (from == null || to == null) {
      await service.clearPending();
      return;
    }

    if (!mounted) return;

    final df = DateFormat('d MMM yyyy');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync calendar dates?'),
        content: Text(
          'Your previous calendar sync for the selected dates '
          '(${df.format(from)} – ${df.format(to)}) did not finish while you '
          'were offline. Sync it now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sync now'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result = await service.resyncPending();
      if (!mounted || result == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Calendar synced — ${result.imported} imported, '
            '${result.updated} updated, ${result.failed} failed.',
          ),
        ),
      );
    } catch (_) {
      // Keep the pending flag so the next reconnect can offer it again.
    }
  }

  String _cacheAgeLabel() {
    final at = ApiClient.lastServedFromCacheAt;
    if (at == null) return '';
    final minutes = DateTime.now().difference(at).inMinutes;
    if (minutes < 1) return ' Showing data from just now.';
    if (minutes < 60) return ' Showing data from $minutes min ago.';
    final hours = (minutes / 60).floor();
    if (hours < 24) return ' Showing data from $hours hr ago.';
    final days = (hours / 24).floor();
    return ' Showing data from $days day${days == 1 ? '' : 's'} ago.';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isConnected && _showSyncedBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF047857),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          (_pendingUploads + _pendingChanges) > 0
                              ? 'Back online. ${_pendingUploads + _pendingChanges} item${(_pendingUploads + _pendingChanges) == 1 ? '' : 's'} still waiting to sync${_conflicts > 0 ? ' · $_conflicts need review' : ''}.'
                              : 'Back online. Your latest changes are synced.',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (!_isConnected && !_dismissed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF78350F),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No internet connection.${_cacheAgeLabel()} Planner, Notes, Tasks and Expenses can still be saved and will sync when you reconnect.',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white70, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _dismissed = true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
