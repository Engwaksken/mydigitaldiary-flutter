import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai_form_assist_service.dart';
import '../services/api_client.dart';

class SocialMediaPlannerScreen extends StatefulWidget {
  const SocialMediaPlannerScreen({super.key});

  @override
  State<SocialMediaPlannerScreen> createState() =>
      _SocialMediaPlannerScreenState();
}

class _SocialMediaPlannerScreenState extends State<SocialMediaPlannerScreen> {
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;

  String _period = 'all';
  DateTime? _from;
  DateTime? _to;

  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int _perPage = 10;

  List<Map<String, dynamic>> _posts = <Map<String, dynamic>>[];

  static const _platformOptions = <String, String>{
    'facebook': 'Facebook',
    'instagram': 'Instagram',
    'x': 'X (Twitter)',
    'linkedin': 'LinkedIn',
    'tiktok': 'TikTok',
    'whatsapp_status': 'WhatsApp Status',
    'whatsapp_channel': 'WhatsApp Channel',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _extractRows(dynamic response) {
    dynamic payload = response;

    if (payload is Map && payload['data'] is Map) {
      payload = payload['data'];
    }

    if (payload is Map && payload['data'] is List) {
      return (payload['data'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    if (payload is Map && payload['items'] is List) {
      return (payload['items'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _meta(dynamic response) {
    dynamic payload = response;

    if (payload is Map && payload['data'] is Map) {
      payload = payload['data'];
    }

    return payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
  }

  Future<void> _load({int? page}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        if (page != null) _page = page;
      });
    }

    final params = <String>[
      'page=$_page',
      'per_page=$_perPage',
      'period=$_period',
    ];

    final q = _search.text.trim();
    if (q.isNotEmpty) params.add('search=${Uri.encodeQueryComponent(q)}');
    if (_period == 'range' && _from != null && _to != null) {
      params.add('from=${_date(_from!)}');
      params.add('to=${_date(_to!)}');
    }

    try {
      final response = await ApiClient.instance.get(
        'social-media-planner?${params.join('&')}',
        cacheable: false,
      );

      final rows = _extractRows(response);
      rows.sort((a, b) {
        DateTime? dateOf(Map<String, dynamic> row) => DateTime.tryParse(
              '${row['scheduled_at'] ?? row['published_at'] ?? row['created_at'] ?? ''}',
            );
        final aDate = dateOf(a);
        final bDate = dateOf(b);
        if (aDate != null && bDate != null) return bDate.compareTo(aDate);
        final aId = int.tryParse('${a['id'] ?? 0}') ?? 0;
        final bId = int.tryParse('${b['id'] ?? 0}') ?? 0;
        return bId.compareTo(aId);
      });
      final meta = _meta(response);

      if (!mounted) return;

      setState(() {
        _posts = rows;
        _page = int.tryParse('${meta['current_page'] ?? _page}') ?? _page;
        _lastPage = int.tryParse('${meta['last_page'] ?? 1}') ?? 1;
        _total = int.tryParse('${meta['total'] ?? rows.length}') ?? rows.length;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load Social Media Planner.';
      });
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
    );

    if (picked == null) return;

    setState(() {
      _period = 'range';
      _from = picked.start;
      _to = picked.end;
    });

    await _load(page: 1);
  }

  DateTime? _scheduledAt(Map<String, dynamic> post) {
    return DateTime.tryParse(post['scheduled_at']?.toString() ?? '')?.toLocal();
  }

  String _status(Map<String, dynamic> post) =>
      (post['status'] ?? 'draft').toString();

  List<String> _platforms(Map<String, dynamic> post) {
    final raw = post['platforms'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return <String>[];
  }

  String? _mediaUrl(Map<String, dynamic> post) {
    final direct = (post['media_url'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final fullPost = post['full_post'];
    if (fullPost is Map) {
      final value = (fullPost['media_url'] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    return null;
  }

  String? _linkUrl(Map<String, dynamic> post) {
    final direct = (post['link_url'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final fullPost = post['full_post'];
    if (fullPost is Map) {
      final value = (fullPost['link_url'] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    final platformContent = post['platform_content'];
    if (platformContent is Map) {
      final value = (platformContent['link_url'] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    return null;
  }

  Future<void> _openUrl(String? value) async {
    if ((value ?? '').isEmpty) return;

    final uri = Uri.tryParse(value!);
    if (uri == null) return;

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _message('Could not open that link.');
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _shareCombinedPost(
    Map<String, dynamic> full,
    Map<String, dynamic> data,
  ) async {
    final text = (full['text'] ?? data['text'] ?? '').toString().trim();
    final mediaUrl =
        (full['media_url'] ?? data['media_url'] ?? '').toString().trim();

    try {
      if (mediaUrl.isEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: (full['title'] ?? data['title'] ?? '').toString(),
          ),
        );
        return;
      }

      final uri = Uri.tryParse(mediaUrl);
      if (uri == null) {
        throw const FormatException('Invalid media URL.');
      }

      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close(force: true);
        throw HttpException(
          'Could not download media (${response.statusCode}).',
        );
      }

      final bytes = await response.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );

      client.close(force: true);

      final path = uri.path.toLowerCase();
      final extension = path.endsWith('.mp4')
          ? '.mp4'
          : path.endsWith('.webm')
              ? '.webm'
              : path.endsWith('.mov')
                  ? '.mov'
                  : path.endsWith('.png')
                      ? '.png'
                      : path.endsWith('.webp')
                          ? '.webp'
                          : path.endsWith('.gif')
                              ? '.gif'
                              : '.jpg';

      final file = File(
        '${Directory.systemTemp.path}/my-digital-diary-social-'
        '${DateTime.now().millisecondsSinceEpoch}$extension',
      );

      await file.writeAsBytes(bytes, flush: true);

      /*
       * ONE share request with both the file and text.
       *
       * Apps such as WhatsApp can then render the image/video first and use
       * the full post text as the media caption, instead of creating one text
       * message and a second media message.
       */
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: text,
          subject: (full['title'] ?? data['title'] ?? '').toString(),
        ),
      );
    } catch (_) {
      // If the media cannot be downloaded, do not lose the post copy.
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: (full['title'] ?? data['title'] ?? '').toString(),
        ),
      );

      _message(
        'The media could not be attached automatically, so the post text was shared instead.',
      );
    }
  }

  Future<void> _postNow(Map<String, dynamic> post) async {
    final id = post['id'];
    if (id == null) return;

    try {
      final response = await ApiClient.instance.post(
        'social-media-planner/$id/post-now',
        const <String, dynamic>{},
      );

      dynamic data = response;
      if (data is Map && data['data'] is Map) data = data['data'];

      final full = data is Map && data['full_post'] is Map
          ? Map<String, dynamic>.from(data['full_post'] as Map)
          : <String, dynamic>{};

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: .78,
          minChildSize: .45,
          maxChildSize: .95,
          expand: false,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                'Full post ready',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'This combines the title, caption, call to action, hashtags and '
                'attached link. Image/video remains attached to the same post.',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _shareCombinedPost(full, Map<String, dynamic>.from(data as Map)),
                icon: const Icon(Icons.share_rounded),
                label: Text(
                  ((full['media_url'] ?? data?['media_url']) != null)
                      ? 'Share image/video with text'
                      : 'Share full post',
                ),
              ),
              const SizedBox(height: 12),
              if ((full['media_url'] ?? data?['media_url']) != null) ...[
                OutlinedButton.icon(
                  onPressed: () => _openUrl(
                    (full['media_url'] ?? data?['media_url']).toString(),
                  ),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('View image / video'),
                ),
                const SizedBox(height: 12),
              ],
              if ((full['title'] ?? '').toString().trim().isNotEmpty) ...[
                Text(
                  (full['title'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if ((full['caption'] ?? '').toString().trim().isNotEmpty) ...[
                SelectableText(
                  (full['caption'] ?? '').toString(),
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 12),
              ],
              if ((full['call_to_action'] ?? '').toString().trim().isNotEmpty) ...[
                Text(
                  (full['call_to_action'] ?? '').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if ((full['link_url'] ?? data?['link_url']) != null) ...[
                SelectableText(
                  (full['link_url'] ?? data?['link_url']).toString(),
                  style: const TextStyle(
                    color: Color(0xFF0284C7),
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openUrl(
                    (full['link_url'] ?? data?['link_url']).toString(),
                  ),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Open attached link'),
                ),
                const SizedBox(height: 12),
              ],
              if ((full['hashtags'] ?? '').toString().trim().isNotEmpty)
                SelectableText(
                  (full['hashtags'] ?? '').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
            ],
          ),
        ),
      );

      await _load();
    } on ApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> post) async {
    final id = post['id'];
    if (id == null) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: Text((post['title'] ?? 'This post').toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    try {
      await ApiClient.instance.delete('social-media-planner/$id');
      await _load();
      _message('Post deleted.');
    } on ApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final title = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final caption = TextEditingController(
      text: existing?['caption']?.toString() ?? '',
    );
    final hashtags = TextEditingController(
      text: existing?['hashtags']?.toString() ?? '',
    );

    final platformContent = existing?['platform_content'] is Map
        ? Map<String, dynamic>.from(existing!['platform_content'] as Map)
        : <String, dynamic>{};

    final objective = TextEditingController(
      text: (platformContent['content_objective'] ?? '').toString(),
    );
    final mediaIdea = TextEditingController(
      text: (platformContent['media_idea'] ?? '').toString(),
    );
    final cta = TextEditingController(
      text: (platformContent['call_to_action'] ?? '').toString(),
    );
    final link = TextEditingController(
      text: (platformContent['link_url'] ?? '').toString(),
    );

    final platforms = _platforms(existing ?? <String, dynamic>{}).toSet();
    if (platforms.isEmpty) platforms.add('facebook');

    DateTime? scheduled = _scheduledAt(existing ?? <String, dynamic>{});
    String postingMode =
        (existing?['posting_mode'] ?? 'manual').toString() == 'automatic'
            ? 'automatic'
            : 'manual';

    bool generating = false;
    String? aiMessage;
    String? localError;

    try {
      final save = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: .94,
          minChildSize: .65,
          maxChildSize: .98,
          expand: false,
          builder: (context, scrollController) => Material(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(26)),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: StatefulBuilder(
              builder: (context, setLocal) {
                Future<void> generate() async {
                  if (title.text.trim().isEmpty) {
                    setLocal(() => aiMessage =
                        'Enter the post title or topic first.');
                    return;
                  }

                  setLocal(() {
                    generating = true;
                    aiMessage =
                        'Creating a short, natural 3–5 paragraph caption from the title...';
                  });

                  try {
                    final draft = await const AiFormAssistService().generate(
                      module: 'social-media-planner',
                      topic: title.text.trim(),
                      context: <String, dynamic>{
                        'platforms': platforms.toList(growable: false),
                      },
                    );

                    caption.text = (draft['caption'] ?? '').toString();
                    hashtags.text = (draft['hashtags'] ?? '').toString();
                    objective.text =
                        (draft['content_objective'] ?? '').toString();
                    mediaIdea.text = (draft['media_idea'] ?? '').toString();
                    cta.text = (draft['call_to_action'] ?? '').toString();

                    setLocal(() {
                      aiMessage =
                          'Draft ready. Caption and hashtags are separate. '
                          'Review and edit before saving.';
                    });
                  } catch (_) {
                    setLocal(() {
                      aiMessage =
                          'AI could not prepare a draft. Your fields were kept.';
                    });
                  } finally {
                    setLocal(() => generating = false);
                  }
                }

                Future<void> chooseSchedule() async {
                  final now = DateTime.now();
                  final initial = scheduled ?? now.add(const Duration(hours: 1));

                  final day = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (day == null) return;

                  if (mounted) {
                    final time = await showTimePicker(
                      // ignore: use_build_context_synchronously
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(initial),
                    );
                    if (time == null) return;

                    setLocal(() {
                      scheduled = DateTime(
                        day.year,
                        day.month,
                        day.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }

                void validateAndClose() {
                  if (title.text.trim().isEmpty) {
                    setLocal(() => localError = 'Enter the post title.');
                    return;
                  }

                  if (platforms.isEmpty) {
                    setLocal(
                      () => localError = 'Select at least one platform.',
                    );
                    return;
                  }

                  Navigator.pop(sheetContext, true);
                }

                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF94A3B8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          18,
                          18,
                          18,
                          MediaQuery.viewInsetsOf(context).bottom + 28,
                        ),
                        children: [
                          Text(
                            existing == null
                                ? 'Create Social Media Post'
                                : 'Edit Social Media Post',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: title,
                            decoration: const InputDecoration(
                              labelText: 'Post title *',
                              hintText: 'Enter the title/topic first',
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: generating ? null : generate,
                            icon: generating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_outlined),
                            label: Text(
                              generating ? 'Generating...' : 'AI Generate',
                            ),
                          ),
                          if ((aiMessage ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              aiMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: caption,
                            minLines: 8,
                            maxLines: 14,
                            decoration: const InputDecoration(
                              labelText: 'Caption',
                              helperText:
                                  'AI Generate creates 3–5 short, natural paragraphs here.',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: hashtags,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Hashtags',
                              helperText:
                                  'Hashtags are stored separately from the caption.',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: objective,
                            decoration: const InputDecoration(
                              labelText: 'Content objective',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: mediaIdea,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Media idea',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: cta,
                            decoration: const InputDecoration(
                              labelText: 'Call to action',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: link,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Link (optional)',
                              helperText:
                                  'Share uses one combined media post: image/video first, with title, caption, call to action, link and hashtags attached as the text below it.',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Platforms',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _platformOptions.entries.map((entry) {
                              final selected = platforms.contains(entry.key);
                              return FilterChip(
                                selected: selected,
                                label: Text(entry.value),
                                onSelected: (checked) => setLocal(() {
                                  if (checked) {
                                    platforms.add(entry.key);
                                  } else {
                                    platforms.remove(entry.key);
                                  }
                                }),
                              );
                            }).toList(growable: false),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: postingMode,
                            decoration:
                                const InputDecoration(labelText: 'Posting mode'),
                            items: const [
                              DropdownMenuItem(
                                value: 'manual',
                                child: Text('Manual / Post Now'),
                              ),
                              DropdownMenuItem(
                                value: 'automatic',
                                child: Text('Automatic'),
                              ),
                            ],
                            onChanged: (value) => setLocal(
                              () => postingMode = value ?? 'manual',
                            ),
                          ),
                          const SizedBox(height: 10),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Schedule'),
                            subtitle: Text(
                              scheduled == null
                                  ? 'No schedule'
                                  : DateFormat('d MMM yyyy · h:mm a')
                                      .format(scheduled!),
                            ),
                            trailing:
                                const Icon(Icons.schedule_rounded),
                            onTap: chooseSchedule,
                          ),
                          if (scheduled != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () =>
                                    setLocal(() => scheduled = null),
                                icon: const Icon(Icons.clear_rounded),
                                label: const Text('Clear schedule'),
                              ),
                            ),
                          if ((localError ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              localError!,
                              style: const TextStyle(
                                color: Color(0xFFBE123C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: validateAndClose,
                            icon: const Icon(Icons.save_outlined),
                            label:
                                Text(existing == null ? 'Save Post' : 'Update Post'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      if (save != true) return;

      final body = <String, dynamic>{
        'title': title.text.trim(),
        'caption': caption.text.trim().isEmpty ? null : caption.text.trim(),
        'hashtags':
            hashtags.text.trim().isEmpty ? null : hashtags.text.trim(),
        'content_objective':
            objective.text.trim().isEmpty ? null : objective.text.trim(),
        'media_idea':
            mediaIdea.text.trim().isEmpty ? null : mediaIdea.text.trim(),
        'call_to_action': cta.text.trim().isEmpty ? null : cta.text.trim(),
        'link_url': link.text.trim().isEmpty ? null : link.text.trim(),
        'platforms': platforms.toList(growable: false),
        'posting_mode': postingMode,
        'scheduled_at': scheduled?.toIso8601String(),
      };

      if (existing == null) {
        await ApiClient.instance.post('social-media-planner', body);
      } else {
        await ApiClient.instance.put(
          'social-media-planner/${existing['id']}',
          body,
        );
      }

      await _load(page: 1);
      _message(existing == null ? 'Post saved.' : 'Post updated.');
    } on ApiException catch (error) {
      _message(error.message);
    } finally {
      title.dispose();
      caption.dispose();
      hashtags.dispose();
      objective.dispose();
      mediaIdea.dispose();
      cta.dispose();
      link.dispose();
    }
  }

  Widget _filterBar() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(page: 1),
              decoration: InputDecoration(
                labelText: 'Search posts',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          _load(page: 1);
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _period,
                    decoration: const InputDecoration(labelText: 'Period'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All time')),
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(
                        value: 'week',
                        child: Text('Last 7 days'),
                      ),
                      DropdownMenuItem(
                        value: 'month',
                        child: Text('This month'),
                      ),
                      DropdownMenuItem(
                        value: 'three_months',
                        child: Text('Last 3 months'),
                      ),
                      DropdownMenuItem(
                        value: 'range',
                        child: Text('Custom range'),
                      ),
                    ],
                    onChanged: (value) async {
                      final selected = value ?? 'all';
                      if (selected == 'range') {
                        await _pickRange();
                      } else {
                        setState(() => _period = selected);
                        await _load(page: 1);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 106,
                  child: DropdownButtonFormField<int>(
                    initialValue: _perPage,
                    decoration: const InputDecoration(labelText: 'Per page'),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 25, child: Text('25')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                    ],
                    onChanged: (value) async {
                      setState(() => _perPage = value ?? 10);
                      await _load(page: 1);
                    },
                  ),
                ),
              ],
            ),
            if (_period == 'range' && _from != null && _to != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${DateFormat('d MMM yyyy').format(_from!)} – '
                  '${DateFormat('d MMM yyyy').format(_to!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final scheduled = _scheduledAt(post);
    final mediaUrl = _mediaUrl(post);
    final link = _linkUrl(post);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    (post['title'] ?? 'Untitled post').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    _status(post).replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if ((post['caption'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                post['caption'].toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _platforms(post)
                  .map(
                    (platform) => Chip(
                      label: Text(
                        _platformOptions[platform] ?? platform,
                        style: const TextStyle(fontSize: 10),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
            if (scheduled != null) ...[
              const SizedBox(height: 8),
              Text(
                DateFormat('d MMM yyyy · h:mm a').format(scheduled),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (mediaUrl != null || link != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (mediaUrl != null)
                    TextButton.icon(
                      onPressed: () => _openUrl(mediaUrl),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Image / Video'),
                    ),
                  if (link != null)
                    TextButton.icon(
                      onPressed: () => _openUrl(link),
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Link'),
                    ),
                ],
              ),
            ],
            const Divider(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openForm(post),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                FilledButton.icon(
                  onPressed: () => _postNow(post),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Post Now'),
                ),
                TextButton.icon(
                  onPressed: () => _delete(post),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagination() {
    if (_lastPage <= 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Text(
          'Showing ${_posts.length} of $_total posts',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _page <= 1 ? null : () => _load(page: _page - 1),
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Previous'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$_page / $_lastPage',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _page >= _lastPage ? null : () => _load(page: _page + 1),
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Next'),
              iconAlignment: IconAlignment.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Media Planner'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Post'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            _filterBar(),
            if (_loading && _posts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _posts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 46),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (_posts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.campaign_outlined, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No social media posts found.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._posts.map(_postCard),
            if (_posts.isNotEmpty) _pagination(),
          ],
        ),
      ),
    );
  }
}
