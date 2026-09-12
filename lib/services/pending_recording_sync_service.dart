import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'meeting_recording_service.dart';

class PendingRecording {
  final String localId;
  final int meetingId;
  final String meetingTitle;
  final String audioPath;
  final int durationSeconds;
  final String createdAt;
  final String fileName;
  final String contentType;

  PendingRecording({
    required this.localId,
    required this.meetingId,
    required this.meetingTitle,
    required this.audioPath,
    required this.durationSeconds,
    required this.createdAt,
    this.fileName = 'recording.m4a',
    this.contentType = 'audio/mp4',
  });

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'meetingId': meetingId,
        'meetingTitle': meetingTitle,
        'audioPath': audioPath,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt,
        'fileName': fileName,
        'contentType': contentType,
      };

  factory PendingRecording.fromJson(Map<String, dynamic> json) =>
      PendingRecording(
        localId: json['localId'].toString(),
        meetingId: _asInt(json['meetingId']),
        meetingTitle: json['meetingTitle']?.toString() ?? '',
        audioPath: json['audioPath'].toString(),
        durationSeconds: _asInt(json['durationSeconds']),
        createdAt: json['createdAt']?.toString() ?? '',
        fileName: json['fileName']?.toString() ??
            _fileNameFromPath(json['audioPath']?.toString()),
        contentType: json['contentType']?.toString() ??
            _contentTypeFromName(
                json['fileName']?.toString() ?? json['audioPath']?.toString()),
      );

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _fileNameFromPath(String? path) {
    if (path == null || path.isEmpty) return 'recording.m4a';
    return path.replaceAll('\\', '/').split('/').last;
  }

  static String _contentTypeFromName(String? name) {
    final lower = (name ?? '').toLowerCase();
    const mimeByExtension = <String, String>{
      '.mp3': 'audio/mpeg',
      '.mp2': 'audio/mpeg',
      '.m4a': 'audio/mp4',
      '.m4b': 'audio/mp4',
      '.mp4': 'audio/mp4',
      '.aac': 'audio/aac',
      '.adts': 'audio/aac',
      '.wav': 'audio/wav',
      '.wave': 'audio/wav',
      '.ogg': 'audio/ogg',
      '.oga': 'audio/ogg',
      '.opus': 'audio/opus',
      '.webm': 'audio/webm',
      '.weba': 'audio/webm',
      '.flac': 'audio/flac',
      '.amr': 'audio/amr',
      '.awb': 'audio/amr-wb',
      '.3gp': 'audio/3gpp',
      '.3gpp': 'audio/3gpp',
      '.3g2': 'audio/3gpp2',
      '.caf': 'audio/x-caf',
      '.aif': 'audio/aiff',
      '.aiff': 'audio/aiff',
      '.aifc': 'audio/aiff',
      '.wma': 'audio/x-ms-wma',
      '.mid': 'audio/midi',
      '.midi': 'audio/midi',
      '.ac3': 'audio/ac3',
      '.eac3': 'audio/eac3',
      '.mka': 'audio/x-matroska',
    };
    for (final entry in mimeByExtension.entries) {
      if (lower.endsWith(entry.key)) return entry.value;
    }
    return 'application/octet-stream';
  }
}

class PendingRecordingSyncService {
  static const _storageKey = 'pending_meeting_recordings';
  final _service = MeetingRecordingService();

  Future<List<PendingRecording>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    final result = <PendingRecording>[];
    for (final value in raw) {
      try {
        result.add(PendingRecording.fromJson(
            Map<String, dynamic>.from(jsonDecode(value))));
      } catch (_) {
        // Ignore a single corrupt queue row rather than breaking all syncing.
      }
    }
    return result;
  }

  Future<void> _writeAll(List<PendingRecording> recordings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      recordings.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  /// Copies queued audio into application support storage so Android/iOS can't
  /// remove it with temporary/cache cleanup before the next retry.
  Future<void> add(PendingRecording recording) async {
    final source = File(recording.audioPath);
    var persistentPath = recording.audioPath;

    if (await source.exists()) {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/pending_recordings');
      if (!await dir.exists()) await dir.create(recursive: true);

      final safeName =
          recording.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final target = File('${dir.path}/${recording.localId}_$safeName');
      if (source.path != target.path) {
        await source.copy(target.path);
        persistentPath = target.path;
      }
    }

    final all = await _readAll();
    all.removeWhere((r) => r.localId == recording.localId);
    all.add(PendingRecording(
      localId: recording.localId,
      meetingId: recording.meetingId,
      meetingTitle: recording.meetingTitle,
      audioPath: persistentPath,
      durationSeconds: recording.durationSeconds,
      createdAt: recording.createdAt,
      fileName: recording.fileName,
      contentType: recording.contentType,
    ));
    await _writeAll(all);
  }

  Future<List<PendingRecording>> pendingFor(int meetingId) async {
    final all = await _readAll();
    return all.where((r) => r.meetingId == meetingId).toList();
  }

  Future<int> pendingCount() async => (await _readAll()).length;

  Future<void> remove(String localId, {bool deleteFile = true}) async {
    final all = await _readAll();
    final matches = all.where((r) => r.localId == localId).toList();
    all.removeWhere((r) => r.localId == localId);
    await _writeAll(all);

    if (deleteFile) {
      for (final recording in matches) {
        try {
          final file = File(recording.audioPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> syncAll() async {
    final all = await _readAll();
    if (all.isEmpty) return;

    final stillPending = <PendingRecording>[];

    for (final recording in all) {
      try {
        final file = File(recording.audioPath);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        await _service.upload(
          meetingId: recording.meetingId,
          audioBytes: bytes,
          durationSeconds: recording.durationSeconds,
          fileName: recording.fileName,
          contentType: recording.contentType,
        );

        await file.delete();
      } on ApiException catch (_) {
        stillPending.add(recording);
      } catch (_) {
        stillPending.add(recording);
      }
    }

    await _writeAll(stillPending);
  }
}
