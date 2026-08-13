import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_client.dart';
import '../services/pending_recording_sync_service.dart';

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

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _subscription = _connectivity.onConnectivityChanged.listen(_handleResult);
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
      PendingRecordingSyncService().syncAll();
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
      PendingRecordingSyncService().syncAll();
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF78350F),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No internet connection.${_cacheAgeLabel()} New changes won\'t be saved until you\'re back online.',
                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 18),
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
