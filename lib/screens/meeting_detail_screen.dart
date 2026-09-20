import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/meeting.dart';
import '../models/meeting_recording.dart';
import '../services/meeting_recording_service.dart';
import '../services/pending_recording_sync_service.dart';
import '../services/api_client.dart';
import '../widgets/confirm_action_dialog.dart';
import 'api_keys_screen.dart';
import 'extra_recording_quota_screen.dart';

/// Recording, transcript, and AI summary for one meeting — the mobile
/// equivalent of the web app's MediaRecorder-based flow, using the
/// `record` package for the microphone capture. Same consent-first,
/// start/pause/resume/stop shape; audio playback opens externally via
/// url_launcher rather than an embedded player, to avoid pulling in yet
/// another unverified package for something the device's own audio
/// handling already does fine.
class MeetingDetailScreen extends StatefulWidget {
  final Meeting meeting;

  const MeetingDetailScreen({super.key, required this.meeting});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final _service = MeetingRecordingService();
  final _recorder = AudioRecorder();

  List<MeetingRecording> _recordings = [];
  bool _loading = true;

  int? _activeRecordingId;
  String _recordingStatus = 'idle'; // idle, recording, paused
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _currentAudioPath;
  List<PendingRecording> _pendingRecordings = [];
  bool _uploadingRecording = false;
  String _transcriptionLanguage = 'en-GB';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pending = await PendingRecordingSyncService().pendingFor(
      widget.meeting.id,
    );
    try {
      final recordings = await _service.list(widget.meeting.id);
      setState(() {
        _recordings = recordings;
        _pendingRecordings = pending;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _pendingRecordings = pending;
        _loading = false;
      });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      // No connection — still show whatever's pending locally even
      // though the server-side recordings list couldn't be fetched.
      setState(() {
        _pendingRecordings = pending;
        _loading = false;
      });
    }
  }

  void _showMessage(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), duration: duration));
  }

  bool _isNetworkFailure(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException;
  }

  String _fileNameFromPath(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }

  String _recordingContentType(String fileName) {
    final lower = fileName.toLowerCase();

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

  Future<void> _queueForRetry({
    required String path,
    required int durationSeconds,
    required String fileName,
    required String contentType,
  }) async {
    await PendingRecordingSyncService().add(
      PendingRecording(
        localId: DateTime.now().microsecondsSinceEpoch.toString(),
        meetingId: widget.meeting.id,
        meetingTitle: widget.meeting.title,
        audioPath: path,
        durationSeconds: durationSeconds,
        createdAt: DateTime.now().toIso8601String(),
        fileName: fileName,
        contentType: contentType,
      ),
    );
    final pending = await PendingRecordingSyncService().pendingFor(
      widget.meeting.id,
    );
    if (mounted) setState(() => _pendingRecordings = pending);
  }

  Future<void> _handleUploadFailure({
    required Object error,
    required String path,
    required int durationSeconds,
    required String fileName,
    required String contentType,
  }) async {
    await _queueForRetry(
      path: path,
      durationSeconds: durationSeconds,
      fileName: fileName,
      contentType: contentType,
    );

    if (_isNetworkFailure(error)) {
      _showMessage(
        'The server could not be reached. The recording is saved safely on this phone and will retry automatically.',
        duration: const Duration(seconds: 6),
      );
    } else if (error is ApiException) {
      _showMessage(
        'Upload failed: ${error.message}. The recording is saved on this phone for retry.',
        duration: const Duration(seconds: 7),
      );
    } else {
      _showMessage(
        'Upload failed: $error. The recording is saved on this phone for retry.',
        duration: const Duration(seconds: 7),
      );
    }
  }

  Future<void> _showConsentDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recording Consent'),
        content: const Text(
          "You're about to record this meeting's audio. Make sure everyone present is aware and has "
          'agreed to being recorded, in line with your local laws on recording consent. The recording, '
          'its transcript, and any AI-generated summary will be stored under this meeting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('I Confirm — Start'),
          ),
        ],
      ),
    );

    if (confirmed == true) _startRecording();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record.'),
          ),
        );
      }
      return;
    }

    // No network call here at all — the server-side recording record
    // (MeetingRecordingService.start()) is created later, at stop
    // time, once real audio actually exists to go with it. This is
    // what lets recording work with zero connectivity: capture is
    // 100% local via the `record` package regardless of whether the
    // device is online.
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/meeting_${widget.meeting.id}_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: path,
    );

    setState(() {
      _currentAudioPath = path;
      _recordingStatus = 'recording';
      _elapsedSeconds = 0;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _elapsedSeconds++),
    );
  }

  Future<void> _pauseRecording() async {
    await _recorder.pause();
    _timer?.cancel();
    setState(() => _recordingStatus = 'paused');
    if (_activeRecordingId != null) {
      await _service.updateStatus(
        _activeRecordingId!,
        'paused',
        _elapsedSeconds,
      );
    }
  }

  Future<void> _resumeRecording() async {
    await _recorder.resume();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _elapsedSeconds++),
    );
    setState(() => _recordingStatus = 'recording');
    if (_activeRecordingId != null) {
      await _service.updateStatus(
        _activeRecordingId!,
        'recording',
        _elapsedSeconds,
      );
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    final finalPath = path ?? _currentAudioPath;
    final duration = _elapsedSeconds;

    if (mounted) {
      setState(() {
        _recordingStatus = 'idle';
        _currentAudioPath = null;
      });
    }

    if (finalPath == null) {
      _showMessage('Recording stopped, but no audio file was created.');
      return;
    }

    final fileName = _fileNameFromPath(finalPath);
    final contentType = _recordingContentType(fileName);

    try {
      final file = File(finalPath);
      if (!await file.exists()) {
        _showMessage('The recorded audio file could not be found.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showMessage('The recorded audio file is empty.');
        return;
      }

      await _service.upload(
        meetingId: widget.meeting.id,
        audioBytes: bytes,
        durationSeconds: duration,
        fileName: fileName,
        contentType: contentType,
      );

      if (await file.exists()) await file.delete();
      _showMessage('Recording uploaded successfully.');
      await _load();
    } catch (error) {
      await _handleUploadFailure(
        error: error,
        path: finalPath,
        durationSeconds: duration,
        fileName: fileName,
        contentType: contentType,
      );
    }
  }

  /// Uploads an EXISTING audio file instead of a live recording —
  /// reuses the exact same server flow _stopRecording() above does
  /// (start() then stop() with the audio bytes), so an upload
  /// attempted while offline automatically benefits from the same
  /// PendingRecordingSyncService queueing rather than needing separate
  /// handling. Duration is sent as 0 (best-effort/cosmetic display
  /// value only) rather than pulling in another package just to read
  /// it from an arbitrary audio file.
  Future<void> _uploadRecording() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        // FileType.audio can hide valid voice-recorder formats on some phones.
        // FileType.any allows MP3, WAV, M4A, AAC, OGG, OPUS, FLAC, AMR,
        // 3GP, WEBM, CAF, WMA, AIFF and other recorder formats.
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
    } catch (error) {
      _showMessage('Could not open the file picker: $error');
      return;
    }

    final picked = result?.files.single;
    if (picked == null) return;

    final fileName = picked.name.trim().isNotEmpty
        ? picked.name
        : (picked.path != null ? _fileNameFromPath(picked.path!) : 'recording');
    final contentType = _recordingContentType(fileName);

    if (mounted) setState(() => _uploadingRecording = true);

    String? retryPath;
    try {
      List<int> bytes;

      if (picked.path != null && picked.path!.isNotEmpty) {
        final file = File(picked.path!);
        if (!await file.exists()) {
          _showMessage('The selected recording file could not be found.');
          return;
        }
        bytes = await file.readAsBytes();
        retryPath = picked.path!;
      } else if (picked.bytes != null) {
        bytes = picked.bytes!;
        final supportDir = await getApplicationSupportDirectory();
        final retryDir = Directory('${supportDir.path}/selected_recordings');
        if (!await retryDir.exists()) await retryDir.create(recursive: true);
        final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final localCopy = File(
          '${retryDir.path}/${DateTime.now().microsecondsSinceEpoch}_$safeName',
        );
        await localCopy.writeAsBytes(bytes, flush: true);
        retryPath = localCopy.path;
      } else {
        _showMessage(
          'The selected recording could not be read on this device.',
        );
        return;
      }

      if (bytes.isEmpty) {
        _showMessage('The selected recording file is empty.');
        return;
      }

      await _service.upload(
        meetingId: widget.meeting.id,
        audioBytes: bytes,
        durationSeconds: 0,
        fileName: fileName,
        contentType: contentType,
      );

      if (picked.path == null) {
        final localCopy = File(retryPath);
        if (await localCopy.exists()) await localCopy.delete();
      }

      _showMessage('Recording uploaded successfully.');
      await _load();
    } catch (error) {
      if (retryPath != null) {
        await _handleUploadFailure(
          error: error,
          path: retryPath,
          durationSeconds: 0,
          fileName: fileName,
          contentType: contentType,
        );
      } else {
        _showMessage(
          'Upload failed: $error',
          duration: const Duration(seconds: 7),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingRecording = false);
    }
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openAudio(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _joinMeeting() async {
    final url = widget.meeting.diaryJoinUrl;
    if (url == null) return;

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showMessage('Could not open the meeting link.');
    }
  }

  Widget _meetingDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _meetingDetailsCard() {
    final meeting = widget.meeting;
    const weekdays = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final repeatOn = meeting.recurrenceDaysOfWeek
        .map((day) => weekdays[day])
        .whereType<String>()
        .join(', ');
    final repeat =
        meeting.recurrenceFrequency == null ||
            meeting.recurrenceFrequency!.isEmpty
        ? 'Does not repeat'
        : '${meeting.recurrenceFrequency![0].toUpperCase()}${meeting.recurrenceFrequency!.substring(1)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meeting Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _meetingDetailRow(
              Icons.schedule,
              'Start',
              DateFormat('d MMM y, h:mm a').format(meeting.startAt),
            ),
            if (meeting.endAt != null)
              _meetingDetailRow(
                Icons.event_available,
                'End',
                DateFormat('d MMM y, h:mm a').format(meeting.endAt!),
              ),
            _meetingDetailRow(
              Icons.info_outline,
              'Status',
              meeting.status[0].toUpperCase() + meeting.status.substring(1),
            ),
            if (meeting.location?.trim().isNotEmpty == true)
              _meetingDetailRow(
                Icons.location_on_outlined,
                'Location',
                meeting.location!,
              ),
            if (meeting.attendees?.trim().isNotEmpty == true)
              _meetingDetailRow(
                Icons.people_outline,
                'Attendees',
                meeting.attendees!,
              ),
            _meetingDetailRow(Icons.repeat, 'Repeat', repeat),
            if (repeatOn.isNotEmpty)
              _meetingDetailRow(
                Icons.calendar_view_week,
                'Repeat on',
                repeatOn,
              ),
            if (meeting.recurrenceEndsAt != null)
              _meetingDetailRow(
                Icons.event_busy,
                'Repeat until',
                DateFormat.yMMMd().format(meeting.recurrenceEndsAt!),
              ),
            if (meeting.notes?.trim().isNotEmpty == true)
              _meetingDetailRow(
                Icons.notes_outlined,
                'Notes / Agenda',
                meeting.notes!,
              ),
            if (meeting.diaryJoinUrl != null)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _joinMeeting,
                  icon: const Icon(Icons.login),
                  label: const Text('Join Meeting'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds one combined, readable text block from whatever's actually
  /// available — full transcript (segments if present, else the plain
  /// transcript field) and, if generated, every section of the AI
  /// summary — then hands it to the native share sheet. Same "share
  /// what's there, skip what isn't" approach as the rest of this
  /// screen's conditional rendering.
  Future<void> _shareTranscriptAndSummary(MeetingRecording recording) async {
    final buffer = StringBuffer();
    buffer.writeln(widget.meeting.title);
    buffer.writeln();

    if (recording.transcriptionStatus == 'completed') {
      buffer.writeln('TRANSCRIPT');
      if (recording.transcriptSegments.isNotEmpty) {
        for (final segment in recording.transcriptSegments) {
          buffer.writeln('[${segment.formattedTimestamp()}] ${segment.text}');
        }
      } else if (recording.transcript != null) {
        buffer.writeln(recording.transcript);
      }
      buffer.writeln();
    }

    if (recording.summaryStatus == 'completed' && recording.summary != null) {
      final summary = recording.summary!;
      buffer.writeln('AI SUMMARY');
      if (summary.mainPoints.isNotEmpty) {
        buffer.writeln('Main Points:');
        for (final point in summary.mainPoints) {
          buffer.writeln('- $point');
        }
        buffer.writeln();
      }
      if (summary.decisions.isNotEmpty) {
        buffer.writeln('Decisions:');
        for (final decision in summary.decisions) {
          buffer.writeln('- $decision');
        }
        buffer.writeln();
      }
      if (summary.actionItems.isNotEmpty) {
        buffer.writeln('Action Items:');
        for (final item in summary.actionItems) {
          final task = item['task'] ?? '';
          final assignee = item['assigned_to'];
          final deadline = item['deadline'];
          buffer.writeln(
            '- $task${assignee != null ? ' — $assignee' : ''}${deadline != null ? ' (due $deadline)' : ''}',
          );
        }
        buffer.writeln();
      }
      if (summary.questionsForFollowup.isNotEmpty) {
        buffer.writeln('Follow-up Questions:');
        for (final question in summary.questionsForFollowup) {
          buffer.writeln('- $question');
        }
      }
    }

    // Same share_plus API-version uncertainty flagged elsewhere in this
    // app — if this doesn't compile, use Share.share(buffer.toString())
    // instead.
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: widget.meeting.title),
    );
  }

  Future<void> _transcribe(MeetingRecording recording) async {
    try {
      await _service.transcribe(recording.id, language: _transcriptionLanguage);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.errorCode == 'recording_too_large') {
        final action = await _showTopUpDialog(
          title: 'Recording too large',
          recording: recording,
        );
        if (action == 'topup') {
          await _retryTranscribe(recording);
        }
        return;
      }
      if (e.errorCode == 'recording_quota_required') {
        final action = await _showTopUpDialog(
          title: 'Recording quota needed',
          recording: recording,
        );
        if (action == 'topup') {
          await _retryTranscribe(recording);
        }
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _retryTranscribe(MeetingRecording recording) async {
    if (!mounted) return;
    try {
      await _service.transcribe(recording.id, language: _transcriptionLanguage);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _formatTranscriptionError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('clipboard') || lower.contains('image input')) {
      return 'This model does not support image input. Please use an audio-only recording or switch to a model that supports audio transcription.';
    }
    return error;
  }

  Future<String?> _showTopUpDialog(
      {required String title, MeetingRecording? recording}) async {
    final message = title == 'Recording quota needed'
        ? 'Your transcription needs an active subscription or extra recording '
              'minutes. Top up to continue transcribing this recording.'
        : 'This recording is bigger than the 30 MB limit, so it can\'t be '
              'transcribed. Please top up your extra recording quota or record a '
              'shorter meeting.';
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'own-key'),
            icon: const Icon(Icons.key_rounded),
            label: const Text('Use My Own API Key'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'topup'),
            icon: const Icon(Icons.credit_card),
            label: const Text('Top Up Quota'),
          ),
        ],
      ),
    );
    if (!mounted) return null;
    if (action == 'topup') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ExtraRecordingQuotaScreen()),
      );
      if (mounted) await _load();
      return 'topup';
    } else if (action == 'own-key') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
      );
      return 'own-key';
    }
    return action;
  }

  Future<void> _summarize(MeetingRecording recording) async {
    try {
      await _service.summarize(recording.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteRecording(MeetingRecording recording) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete this recording?',
      message:
          'This also removes its transcript and summary. This action cannot be undone.',
      confirmText: 'Delete recording',
    );
    if (!confirmed) return;

    try {
      await _service.delete(widget.meeting.id, recording.id);
      setState(() => _recordings.removeWhere((r) => r.id == recording.id));
      _showMessage('Recording deleted.');
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _retryPendingRecordings() async {
    if (mounted) setState(() => _uploadingRecording = true);
    try {
      await PendingRecordingSyncService().syncAll();
      final pending = await PendingRecordingSyncService().pendingFor(
        widget.meeting.id,
      );
      if (!mounted) return;
      setState(() => _pendingRecordings = pending);
      if (pending.isEmpty) {
        _showMessage('Queued recordings uploaded successfully.');
        await _load();
      } else {
        _showMessage(
          '${pending.length} recording${pending.length == 1 ? '' : 's'} still could not be uploaded. Pull to refresh or try again later.',
          duration: const Duration(seconds: 6),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingRecording = false);
    }
  }

  Future<void> _deletePendingRecording(PendingRecording recording) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete queued recording?',
      message:
          'This removes the saved audio from this phone and cannot be undone.',
      confirmText: 'Delete recording',
    );
    if (!confirmed) return;

    await PendingRecordingSyncService().remove(recording.localId);
    final pending = await PendingRecordingSyncService().pendingFor(
      widget.meeting.id,
    );
    if (mounted) {
      setState(() => _pendingRecordings = pending);
      _showMessage('Queued recording deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.meeting.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _meetingDetailsCard(),
                  const SizedBox(height: 16),
                  if (_pendingRecordings.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_upload_outlined,
                            size: 18,
                            color: Color(0xFF92400E),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_pendingRecordings.length} recording${_pendingRecordings.length == 1 ? '' : 's'} saved on this phone and waiting to upload.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: _uploadingRecording
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh,
                                    color: Color(0xFF92400E),
                                  ),
                            tooltip: 'Retry uploads',
                            onPressed: _uploadingRecording
                                ? null
                                : _retryPendingRecordings,
                          ),
                        ],
                      ),
                    ),
                    ..._pendingRecordings.map(
                      (pending) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.schedule_send_outlined),
                          title: Text(
                            pending.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text('Queued for automatic upload'),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            tooltip: 'Delete queued recording',
                            onPressed: () => _deletePendingRecording(pending),
                          ),
                        ),
                      ),
                    ),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recording',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _transcriptionLanguage,
                            decoration: const InputDecoration(
                              labelText: 'Transcription language',
                              prefixIcon: Icon(Icons.language),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'en-GB',
                                child: Text('English'),
                              ),
                              DropdownMenuItem(
                                value: 'lg',
                                child: Text('Luganda'),
                              ),
                              DropdownMenuItem(
                                value: 'sw',
                                child: Text('Kiswahili'),
                              ),
                              DropdownMenuItem(
                                value: 'auto',
                                child: Text('Auto detect'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null)
                                setState(() => _transcriptionLanguage = value);
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Choose the language actually spoken. Recording uses mono voice capture with automatic gain, echo cancellation and noise suppression when supported by the phone.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_recordingStatus == 'idle')
                            Wrap(
                              spacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showConsentDialog,
                                  icon: const Icon(
                                    Icons.fiber_manual_record,
                                    color: Colors.red,
                                  ),
                                  label: const Text('Start Recording'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _uploadingRecording
                                      ? null
                                      : _uploadRecording,
                                  icon: _uploadingRecording
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.upload_outlined),
                                  label: const Text('Upload Recording'),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  color: _recordingStatus == 'recording'
                                      ? Colors.red
                                      : Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _recordingStatus == 'recording'
                                      ? 'Recording'
                                      : 'Paused',
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatTimer(_elapsedSeconds),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                if (_recordingStatus == 'recording')
                                  IconButton(
                                    icon: const Icon(Icons.pause),
                                    onPressed: _pauseRecording,
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: _resumeRecording,
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.stop,
                                    color: Colors.red,
                                  ),
                                  onPressed: _stopRecording,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Past Recordings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_recordings.isNotEmpty)
                    _buildTranscriptionCapacityCard(),
                  if (_recordings.isEmpty) const Text('No recordings yet.'),
                  ..._recordings.map(_buildRecordingCard),
                ],
              ),
            ),
    );
  }

  Widget _buildTranscriptionCapacityCard() {
    final first = _recordings.first;
    final anyHeavy = _recordings.any((r) => r.isOverUploadLimit);
    final canTranscribe = _recordings.any((r) => r.canTranscribe);
    final needsAction = !canTranscribe || anyHeavy;

    final parts = <String>[];
    if (first.hasActiveAccess) {
      parts.add('Active subscription');
    }
    if (first.extraRecordingMinutesRemaining > 0) {
      final expires = first.extraQuotaExpiresAt;
      parts.add(
        '${first.extraRecordingMinutesRemaining} extra min'
        '${expires != null ? ' (exp ${DateFormat('d MMM').format(expires)})' : ''}',
      );
    }
    if (parts.isEmpty) {
      parts.add('No active subscription or extra recording quota');
    }
    if (anyHeavy) {
      parts.add('A recording is over the ${first.transcriptionLimitMb} MB limit');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  canTranscribe ? Icons.check_circle_outline : Icons.lock_outline,
                  size: 18,
                  color: canTranscribe ? Colors.green.shade700 : Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Transcription capacity',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              parts.join(' · '),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            if (needsAction) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openTopUpScreen,
                      icon: const Icon(Icons.credit_card, size: 18),
                      label: const Text('Top Up Quota'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openApiKeysScreen,
                      icon: const Icon(Icons.key_rounded, size: 18),
                      label: const Text('Use My Own API'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openTopUpScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExtraRecordingQuotaScreen()),
    );
    if (mounted) await _load();
  }

  Future<void> _openApiKeysScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
    );
    if (mounted) await _load();
  }

  Widget _buildRecordingCard(MeetingRecording recording) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recording — ${recording.formattedDuration}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRecording(recording),
                ),
              ],
            ),
            if (recording.audioUrl != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.data_usage_rounded,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${recording.fileSizeMb.toStringAsFixed(1)} MB · up to '
                      '${recording.transcriptionLimitMb} MB per recording',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (recording.isOverUploadLimit) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'HEAVY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (recording.audioUrl != null)
              TextButton.icon(
                onPressed: () => _openAudio(recording.audioUrl),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Play Audio'),
              ),
            if (recording.transcriptionStatus == 'completed' ||
                (recording.summaryStatus == 'completed' &&
                    recording.summary != null))
              TextButton.icon(
                onPressed: () => _shareTranscriptAndSummary(recording),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share Transcript & Summary'),
              ),
            const Divider(),
            const Text(
              'Transcript',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (recording.transcriptionStatus == 'completed') ...[
              const SizedBox(height: 6),
              ...recording.transcriptSegments.map(
                (segment) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: '[${segment.formattedTimestamp()}] ',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontFamily: 'monospace',
                          ),
                        ),
                        TextSpan(text: segment.text),
                      ],
                    ),
                  ),
                ),
              ),
              if (recording.transcriptSegments.isEmpty &&
                  recording.transcript != null)
                Text(recording.transcript!),
            ] else if (recording.transcriptionStatus == 'processing') ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Transcribing...'),
                ],
              ),
            ] else ...[
              if (recording.transcriptionStatus == 'failed' &&
                  recording.transcriptionError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _formatTranscriptionError(recording.transcriptionError!),
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              if (!recording.canTranscribe) ...[
                if (recording.transcript != null &&
                    recording.transcriptionStatus != 'completed')
                  OutlinedButton(
                    onPressed: () => _transcribe(recording),
                    child: const Text('Continue Transcription'),
                  ),
                if (recording.transcript == null ||
                    recording.transcriptionStatus == 'pending') ...[
                  const SizedBox(height: 4),
                  Text(
                    'No transcription available. Top up or add an API key to transcribe.',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openTopUpScreen,
                          icon: const Icon(Icons.credit_card, size: 18),
                          label: const Text('Top Up Quota'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openApiKeysScreen,
                          icon: const Icon(Icons.key_rounded, size: 18),
                          label: const Text('Use My Own API'),
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                OutlinedButton(
                  onPressed: () => _transcribe(recording),
                  child: const Text('Transcribe Recording'),
                ),
              ],
            ],
            if (recording.transcript != null) ...[
              const Divider(),
              const Text(
                'AI Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (recording.summaryStatus == 'completed' &&
                  recording.summary != null) ...[
                const SizedBox(height: 6),
                if (recording.summary!.mainPoints.isNotEmpty)
                  _buildSummarySection(
                    'Main Points',
                    recording.summary!.mainPoints,
                  ),
                if (recording.summary!.decisions.isNotEmpty)
                  _buildSummarySection(
                    'Decisions',
                    recording.summary!.decisions,
                  ),
                if (recording.summary!.actionItems.isNotEmpty)
                  _buildSummarySection(
                    'Action Items',
                    recording.summary!.actionItems.map((item) {
                      final task = item['task'] ?? '';
                      final assignee = item['assigned_to'];
                      final deadline = item['deadline'];
                      return '$task${assignee != null ? ' — $assignee' : ''}${deadline != null ? ' (due $deadline)' : ''}';
                    }).toList(),
                  ),
                if (recording.summary!.questionsForFollowup.isNotEmpty)
                  _buildSummarySection(
                    'Follow-up Questions',
                    recording.summary!.questionsForFollowup,
                  ),
              ] else if (recording.summaryStatus == 'processing') ...[
                const SizedBox(height: 6),
                const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Generating summary...'),
                  ],
                ),
              ] else ...[
                if (recording.summaryStatus == 'failed' &&
                    recording.summaryError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      recording.summaryError!,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () => _summarize(recording),
                  child: const Text('Generate Summary'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text('• $item', style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
