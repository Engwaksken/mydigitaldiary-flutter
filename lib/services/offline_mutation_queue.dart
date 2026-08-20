import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'api_client.dart';

class OfflineMutation {
  final String id;
  final String idempotencyKey;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final String module;
  final String label;
  final int? localId;
  final String? baseUpdatedAt;
  final String status; // pending | conflict
  final String? error;
  final DateTime createdAt;

  const OfflineMutation({
    required this.id,
    required this.idempotencyKey,
    required this.method,
    required this.path,
    required this.body,
    required this.module,
    required this.label,
    required this.createdAt,
    this.localId,
    this.baseUpdatedAt,
    this.status = 'pending',
    this.error,
  });

  OfflineMutation copyWith({
    String? path,
    Map<String, dynamic>? body,
    String? status,
    String? error,
    int? localId,
    bool clearBaseUpdatedAt = false,
  }) => OfflineMutation(
        id: id,
        idempotencyKey: idempotencyKey,
        method: method,
        path: path ?? this.path,
        body: body ?? this.body,
        module: module,
        label: label,
        createdAt: createdAt,
        localId: localId ?? this.localId,
        baseUpdatedAt: clearBaseUpdatedAt ? null : baseUpdatedAt,
        status: status ?? this.status,
        error: error,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'idempotency_key': idempotencyKey,
        'method': method,
        'path': path,
        'body': body,
        'module': module,
        'label': label,
        'local_id': localId,
        'base_updated_at': baseUpdatedAt,
        'status': status,
        'error': error,
        'created_at': createdAt.toIso8601String(),
      };

  factory OfflineMutation.fromJson(Map<String, dynamic> json) => OfflineMutation(
        id: json['id']?.toString() ?? const Uuid().v4(),
        idempotencyKey: json['idempotency_key']?.toString() ?? const Uuid().v4(),
        method: json['method']?.toString().toUpperCase() ?? 'POST',
        path: json['path']?.toString() ?? '',
        body: Map<String, dynamic>.from((json['body'] as Map?) ?? const {}),
        module: json['module']?.toString() ?? 'Other',
        label: json['label']?.toString() ?? 'Pending change',
        localId: (json['local_id'] as num?)?.toInt(),
        baseUpdatedAt: json['base_updated_at']?.toString(),
        status: json['status']?.toString() ?? 'pending',
        error: json['error']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class OfflineMutationQueue {
  OfflineMutationQueue._();
  static final OfflineMutationQueue instance = OfflineMutationQueue._();

  static const _storageKey = 'offline_mutation_queue_v1';
  final _api = ApiClient.instance;

  int newLocalId() => -DateTime.now().microsecondsSinceEpoch;

  Future<List<OfflineMutation>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final rows = (jsonDecode(raw) as List).whereType<Map>().map((e) => OfflineMutation.fromJson(Map<String, dynamic>.from(e))).toList();
      rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return rows;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<OfflineMutation> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(rows.map((e) => e.toJson()).toList()));
  }

  Future<int> pendingCount() async => (await all()).length;
  Future<int> conflictCount() async => (await all()).where((e) => e.status == 'conflict').length;

  Future<List<OfflineMutation>> forPrefix(String prefix) async =>
      (await all()).where((e) => e.path == prefix || e.path.startsWith('$prefix/')).toList();

  Future<OfflineMutation> enqueue({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    required String module,
    required String label,
    int? localId,
    String? baseUpdatedAt,
  }) async {
    final rows = await all();
    final mutation = OfflineMutation(
      id: const Uuid().v4(),
      idempotencyKey: const Uuid().v4(),
      method: method.toUpperCase(),
      path: path,
      body: Map<String, dynamic>.from(body),
      module: module,
      label: label,
      localId: localId,
      baseUpdatedAt: baseUpdatedAt,
      createdAt: DateTime.now(),
    );
    rows.add(mutation);
    await _save(rows);
    return mutation;
  }

  Future<bool> updateQueuedCreate(int localId, Map<String, dynamic> body) async {
    final rows = await all();
    final index = rows.indexWhere((e) => e.localId == localId && e.method == 'POST' && e.status == 'pending');
    if (index < 0) return false;
    rows[index] = rows[index].copyWith(body: Map<String, dynamic>.from(body));
    await _save(rows);
    return true;
  }

  Future<void> removeLocalCreate(int localId) async {
    final rows = await all();
    rows.removeWhere((e) => e.localId == localId || e.path.contains('/$localId'));
    await _save(rows);
  }

  Future<void> discard(String id) async {
    final rows = await all();
    rows.removeWhere((e) => e.id == id);
    await _save(rows);
  }

  Future<void> retry(String id) async {
    final rows = await all();
    final index = rows.indexWhere((e) => e.id == id);
    if (index < 0) return;
    rows[index] = rows[index].copyWith(status: 'pending', error: '');
    await _save(rows);
    await syncAll();
  }

  /// Resolves a server-newer conflict in favour of the local copy. This is
  /// deliberately an explicit user action; automatic replay never overwrites
  /// a newer server record silently.
  Future<void> forceLocalVersion(String id) async {
    final rows = await all();
    final index = rows.indexWhere((e) => e.id == id);
    if (index < 0) return;
    rows[index] = rows[index].copyWith(status: 'pending', error: '', clearBaseUpdatedAt: true);
    await _save(rows);
    await syncAll();
  }

  Future<Map<String, int>> syncAll() async {
    var rows = await all();
    final localToServer = <int, int>{};
    var synced = 0;
    var conflicts = 0;

    for (var i = 0; i < rows.length; i++) {
      var mutation = rows[i];
      if (mutation.status == 'conflict') continue;

      var resolvedPath = mutation.path;
      for (final entry in localToServer.entries) {
        resolvedPath = resolvedPath.replaceAll('/${entry.key}', '/${entry.value}');
      }

      try {
        final response = await _api.replayOfflineMutation(
          mutation.method,
          resolvedPath,
          mutation.body,
          idempotencyKey: mutation.idempotencyKey,
          baseUpdatedAt: mutation.baseUpdatedAt,
        );

        if (mutation.localId != null && mutation.method == 'POST' && response is Map) {
          final serverId = (response['id'] as num?)?.toInt();
          if (serverId != null && serverId > 0) {
            localToServer[mutation.localId!] = serverId;
            for (var j = i + 1; j < rows.length; j++) {
              if (rows[j].path.contains('/${mutation.localId}')) {
                rows[j] = rows[j].copyWith(path: rows[j].path.replaceAll('/${mutation.localId}', '/$serverId'));
              }
            }
          }
        }

        rows.removeAt(i);
        i--;
        synced++;
        await _save(rows);
      } on ApiException catch (e) {
        if (e.statusCode == 404 && mutation.method == 'DELETE') {
          rows.removeAt(i);
          i--;
          synced++;
          await _save(rows);
          continue;
        }
        if (e.statusCode == 409 || e.statusCode == 404 || e.statusCode == 422) {
          rows[i] = mutation.copyWith(
            path: resolvedPath,
            status: 'conflict',
            error: e.message,
          );
          conflicts++;
          await _save(rows);
          continue;
        }
        break;
      } catch (_) {
        break;
      }
    }

    return {'synced': synced, 'conflicts': conflicts, 'remaining': rows.length};
  }
}
