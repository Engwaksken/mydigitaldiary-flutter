import 'api_client.dart';
import 'pending_recording_sync_service.dart';
import 'offline_mutation_queue.dart';

class SyncSnapshot {
  final bool online;
  final int pendingUploads;
  final int pendingChanges;
  final int conflicts;
  final DateTime? lastSyncedAt;
  final String timezone;

  const SyncSnapshot({
    required this.online,
    required this.pendingUploads,
    required this.pendingChanges,
    required this.conflicts,
    required this.lastSyncedAt,
    required this.timezone,
  });

  int get totalPending => pendingUploads + pendingChanges;
}

class SyncStatusService {
  final _api = ApiClient.instance;
  final _recordings = PendingRecordingSyncService();
  final _changes = OfflineMutationQueue.instance;

  Future<SyncSnapshot> refresh() async {
    final pendingUploads = await _recordings.pendingCount();
    final pendingChanges = await _changes.pendingCount();
    final conflicts = await _changes.conflictCount();
    try {
      final raw = await _api.get('sync/status');
      final map =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final serverLast =
          DateTime.tryParse(map['last_mobile_write_at']?.toString() ?? '');
      return SyncSnapshot(
        online: true,
        pendingUploads: pendingUploads,
        pendingChanges: pendingChanges,
        conflicts: conflicts,
        lastSyncedAt: ApiClient.lastSuccessfulSyncAt ?? serverLast,
        timezone: map['timezone']?.toString() ?? 'Africa/Kampala',
      );
    } catch (_) {
      return SyncSnapshot(
        online: false,
        pendingUploads: pendingUploads,
        pendingChanges: pendingChanges,
        conflicts: conflicts,
        lastSyncedAt: ApiClient.lastSuccessfulSyncAt,
        timezone: 'Africa/Kampala',
      );
    }
  }
}
