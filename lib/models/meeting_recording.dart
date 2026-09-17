class TranscriptSegment {
  final double startSeconds;
  final double endSeconds;
  final String? speaker;
  final String text;

  TranscriptSegment(
      {required this.startSeconds,
      required this.endSeconds,
      this.speaker,
      required this.text});

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) =>
      TranscriptSegment(
        startSeconds: _asDouble(json['start_seconds']),
        endSeconds: _asDouble(json['end_seconds']),
        speaker: _nullableString(json['speaker']),
        text: json['text']?.toString() ?? '',
      );

  String formattedTimestamp() {
    final minutes = startSeconds ~/ 60;
    final seconds = (startSeconds % 60).toInt();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class MeetingSummary {
  final List<String> mainPoints;
  final List<String> decisions;
  final List<Map<String, dynamic>> actionItems;
  final List<String> questionsForFollowup;

  MeetingSummary(
      {required this.mainPoints,
      required this.decisions,
      required this.actionItems,
      required this.questionsForFollowup});

  factory MeetingSummary.fromJson(Map<String, dynamic> json) => MeetingSummary(
        mainPoints: _stringList(json['main_points']),
        decisions: _stringList(json['decisions']),
        actionItems: _mapList(json['action_items']),
        questionsForFollowup: _stringList(json['questions_for_followup']),
      );
}

class MeetingRecording {
  final int id;
  final int meetingId;
  final String status;
  final int durationSeconds;
  final String formattedDuration;
  final String? audioUrl;
  final int fileSizeBytes;
  final double fileSizeMb;
  final int transcriptionLimitMb;
  final bool isOverUploadLimit;
  final bool hasActiveAccess;
  final int extraRecordingMinutesRemaining;
  final DateTime? extraQuotaExpiresAt;
  final bool canTranscribe;
  final String? transcript;
  final List<TranscriptSegment> transcriptSegments;
  final String transcriptionStatus;
  final String? transcriptionError;
  final MeetingSummary? summary;
  final String summaryStatus;
  final String? summaryError;

  MeetingRecording({
    required this.id,
    required this.meetingId,
    required this.status,
    required this.durationSeconds,
    required this.formattedDuration,
    this.audioUrl,
    this.fileSizeBytes = 0,
    this.fileSizeMb = 0,
    this.transcriptionLimitMb = 30,
    this.isOverUploadLimit = false,
    this.hasActiveAccess = false,
    this.extraRecordingMinutesRemaining = 0,
    this.extraQuotaExpiresAt,
    this.canTranscribe = false,
    this.transcript,
    required this.transcriptSegments,
    required this.transcriptionStatus,
    this.transcriptionError,
    this.summary,
    required this.summaryStatus,
    this.summaryError,
  });

  factory MeetingRecording.fromJson(Map<String, dynamic> json) {
    final segments = <TranscriptSegment>[];
    final rawSegments = json['transcript_segments'];
    if (rawSegments is List) {
      for (final item in rawSegments) {
        if (item is Map)
          segments
              .add(TranscriptSegment.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    MeetingSummary? summary;
    final rawSummary = json['summary'];
    if (rawSummary is Map)
      summary = MeetingSummary.fromJson(Map<String, dynamic>.from(rawSummary));

    final duration = _asInt(json['duration_seconds']);
    return MeetingRecording(
      id: _asInt(json['id']),
      meetingId: _asInt(json['meeting_id']),
      status: json['status']?.toString() ?? '',
      durationSeconds: duration,
      formattedDuration:
          json['formatted_duration']?.toString() ?? _formatDuration(duration),
      audioUrl: _nullableString(json['audio_url']),
      fileSizeBytes: _asInt(json['file_size_bytes']),
      fileSizeMb: _asDouble(json['file_size_mb']),
      transcriptionLimitMb: json['transcription_limit_mb'] is int
          ? json['transcription_limit_mb'] as int
          : (json['transcription_limit_mb'] is num
              ? (json['transcription_limit_mb'] as num).toInt()
              : 30),
      isOverUploadLimit: json['is_over_upload_limit'] == true,
      hasActiveAccess: json['has_active_access'] == true,
      extraRecordingMinutesRemaining: _asInt(
          json['extra_recording_minutes_remaining']),
      extraQuotaExpiresAt:
          _nullableString(json['extra_quota_expires_at']) != null
              ? DateTime.tryParse(json['extra_quota_expires_at'] as String)
                  ?.toLocal()
              : null,
      canTranscribe: json['can_transcribe'] == true,
      transcript: _nullableString(json['transcript']),
      transcriptSegments: segments,
      transcriptionStatus:
          json['transcription_status']?.toString() ?? 'pending',
      transcriptionError: _nullableString(json['transcription_error']),
      summary: summary,
      summaryStatus: json['summary_status']?.toString() ?? 'pending',
      summaryError: _nullableString(json['summary_error']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '') ?? 0;
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final valueString = value.toString();
  return valueString.isEmpty ? null : valueString;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.where((e) => e != null).map((e) => e.toString()).toList();
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
