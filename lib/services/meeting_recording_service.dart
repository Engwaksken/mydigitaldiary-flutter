import '../models/meeting_recording.dart';
import 'api_client.dart';

class MeetingRecordingService {
  final _api = ApiClient.instance;

  Future<List<MeetingRecording>> list(int meetingId) async {
    final response = await _api.get('meetings/$meetingId/recordings');
    final raw = response is Map ? response['data'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => MeetingRecording.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<MeetingRecording> start(int meetingId) async {
    final response =
        await _api.post('meetings/$meetingId/recordings', {'consent': true});
    final data = response is Map ? response['data'] : null;
    if (data is! Map) {
      throw ApiException(
          500, 'The server returned an invalid recording response.');
    }
    return MeetingRecording.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> updateStatus(
      int recordingId, String status, int durationSeconds) async {
    await _api.patch('meeting-recordings/$recordingId/status', {
      'status': status,
      'duration_seconds': durationSeconds,
    });
  }

  Future<MeetingRecording> stop(
    int recordingId,
    List<int> audioBytes,
    int durationSeconds, {
    String fileName = 'recording.m4a',
    String contentType = 'audio/mp4',
  }) async {
    final response = await _api.postMultipart(
      'meeting-recordings/$recordingId/stop',
      fileFieldName: 'audio',
      fileBytes: audioBytes,
      fileName: fileName,
      contentType: contentType,
      fields: {'duration_seconds': durationSeconds.toString()},
    );
    final data = response is Map ? response['data'] : null;
    if (data is! Map) {
      throw ApiException(
          500, 'The server returned an invalid recording response.');
    }
    return MeetingRecording.fromJson(Map<String, dynamic>.from(data));
  }

  /// One safe upload transaction. If the server-side placeholder is created
  /// but the multipart upload fails, clean the placeholder up so a retry does
  /// not create duplicate/empty recordings.
  Future<MeetingRecording> upload({
    required int meetingId,
    required List<int> audioBytes,
    required int durationSeconds,
    required String fileName,
    required String contentType,
  }) async {
    final remote = await start(meetingId);
    try {
      return await stop(
        remote.id,
        audioBytes,
        durationSeconds,
        fileName: fileName,
        contentType: contentType,
      );
    } catch (_) {
      try {
        await delete(meetingId, remote.id);
      } catch (_) {
        // Preserve the original upload error.
      }
      rethrow;
    }
  }

  Future<MeetingRecording> transcribe(int recordingId,
      {String language = 'en-GB'}) async {
    final response =
        await _api.post('meeting-recordings/$recordingId/transcribe', {
      'transcription_language': language,
    });
    final data = response is Map ? response['data'] : null;
    if (data is! Map) {
      throw ApiException(
          500, 'The server returned an invalid recording response.');
    }
    return MeetingRecording.fromJson(Map<String, dynamic>.from(data));
  }

  Future<MeetingRecording> summarize(int recordingId) async {
    final response =
        await _api.post('meeting-recordings/$recordingId/summarize', {});
    final data = response is Map ? response['data'] : null;
    if (data is! Map) {
      throw ApiException(
          500, 'The server returned an invalid recording response.');
    }
    return MeetingRecording.fromJson(Map<String, dynamic>.from(data));
  }

  /// Supports both common route layouts. Existing installations that expose
  /// /meeting-recordings/{id} continue to work; installations using the nested
  /// /meetings/{meeting}/recordings/{recording} route also work.
  Future<void> delete(int meetingId, int recordingId) async {
    try {
      await _api.delete('meeting-recordings/$recordingId');
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      await _api.delete('meetings/$meetingId/recordings/$recordingId');
    }
  }
}
