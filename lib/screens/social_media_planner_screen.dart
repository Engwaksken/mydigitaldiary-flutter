import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/social_media_planner_service.dart';
import 'social_media_accounts_screen.dart';
import 'social_media_report_screen.dart';

class SocialMediaPlannerScreen extends StatefulWidget {
  const SocialMediaPlannerScreen({super.key});

  @override
  State<SocialMediaPlannerScreen> createState() =>
      _SocialMediaPlannerScreenState();
}

class _SocialMediaPlannerScreenState
    extends State<SocialMediaPlannerScreen> {
  final _service = const SocialMediaPlannerService();

  List<Map<String, dynamic>> _posts = <Map<String, dynamic>>[];
  final Set<int> _selected = <int>{};

  bool _loading = true;
  bool _deleting = false;

  bool get _selectionMode => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? _id(Map<String, dynamic> post) {
    final value = post['id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    try {
      final rows = await _service.posts();

      if (!mounted) return;

      setState(() {
        _posts = rows;
        _selected.removeWhere(
          (id) => !_posts.any(
            (post) => _id(post) == id,
          ),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load social media posts: $error',
          ),
        ),
      );
    }
  }

  Future<void> _edit([
    Map<String, dynamic>? post,
  ]) async {
    final title = TextEditingController(
      text: post?['title']?.toString() ?? '',
    );
    final caption = TextEditingController(
      text: post?['caption']?.toString() ?? '',
    );
    final hashtags = TextEditingController(
      text: post?['hashtags']?.toString() ?? '',
    );

    DateTime? scheduledAt = _date(
      post?['scheduled_at'],
    );

    String postingMode =
        (post?['posting_mode'] ?? 'manual').toString();

    final selectedPlatforms = <String>{};

    final rawPlatforms = post?['platforms'];

    if (rawPlatforms is List) {
      selectedPlatforms.addAll(
        rawPlatforms.map((e) => e.toString()),
      );
    }

    if (selectedPlatforms.isEmpty) {
      selectedPlatforms.add('whatsapp_status');
    }

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> pickSchedule() async {
            final now = DateTime.now();

            final date = await showDatePicker(
              context: context,
              initialDate: scheduledAt ?? now,
              firstDate: DateTime(
                now.year,
                now.month,
                now.day,
              ),
              lastDate: now.add(
                const Duration(days: 730),
              ),
            );

            if (date == null || !context.mounted) {
              return;
            }

            final time = await showTimePicker(
              context: context,
              initialTime: scheduledAt == null
                  ? TimeOfDay.now()
                  : TimeOfDay.fromDateTime(
                      scheduledAt!,
                    ),
            );

            if (time == null) return;

            setLocal(() {
              scheduledAt = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            });
          }

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                4,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(
                    post == null
                        ? 'New Social Media Post'
                        : 'Edit Social Media Post',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Post title',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: caption,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Caption',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hashtags,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Hashtags',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Platforms',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: const <String, String>{
                      'instagram': 'Instagram',
                      'facebook': 'Facebook',
                      'x': 'X (Twitter)',
                      'tiktok': 'TikTok',
                      'linkedin': 'LinkedIn',
                      'whatsapp_status':
                          'WhatsApp Status',
                      'whatsapp_channel':
                          'WhatsApp Channel',
                    }.entries.map((entry) {
                      return FilterChip(
                        selected: selectedPlatforms
                            .contains(entry.key),
                        label: Text(entry.value),
                        onSelected: (value) {
                          setLocal(() {
                            if (value) {
                              selectedPlatforms.add(
                                entry.key,
                              );
                            } else {
                              selectedPlatforms.remove(
                                entry.key,
                              );
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Posting method',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'automatic',
                        icon: Icon(Icons.auto_awesome_outlined),
                        label: Text('Automatic'),
                      ),
                      ButtonSegment<String>(
                        value: 'manual',
                        icon: Icon(Icons.notifications_active_outlined),
                        label: Text('Remind me'),
                      ),
                    ],
                    selected: <String>{postingMode},
                    onSelectionChanged: (selection) {
                      setLocal(() {
                        postingMode = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    postingMode == 'automatic'
                        ? 'My Digital Diary will automatically post to every selected platform that has an authorised publishing connection. You will get a 30-minute reminder, a posting notification and a success/failure notification. Unsupported or disconnected platforms fall back to Ready to Post.'
                        : 'At the scheduled time the post becomes Ready to Post and My Digital Diary reminds you.',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickSchedule,
                          icon: const Icon(
                            Icons.schedule_outlined,
                          ),
                          label: Text(
                            scheduledAt == null
                                ? 'Choose schedule'
                                : scheduledAt
                                    .toString()
                                    .substring(0, 16),
                          ),
                        ),
                      ),
                      if (scheduledAt != null)
                        IconButton(
                          tooltip: 'Clear schedule',
                          onPressed: () {
                            setLocal(
                              () => scheduledAt = null,
                            );
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (title.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter a post title.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (selectedPlatforms.isEmpty) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Choose at least one platform.',
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context, true);
                    },
                    child: Text(
                      post == null
                          ? 'Save Post'
                          : 'Update Post',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (save == true) {
      try {
        if (post == null) {
          await _service.create(
            title: title.text,
            caption: caption.text,
            hashtags: hashtags.text,
            mediaType: 'text',
            platforms: selectedPlatforms.toList(),
            scheduledAt: scheduledAt,
            postingMode: postingMode,
          );
        } else {
          final id = _id(post);

          if (id != null) {
            await _service.update(
              id: id,
              title: title.text,
              caption: caption.text,
              hashtags: hashtags.text,
              mediaType:
                  (post['media_type'] ?? 'text')
                      .toString(),
              platforms: selectedPlatforms.toList(),
              scheduledAt: scheduledAt,
              postingMode: postingMode,
            );
          }
        }

        await _load();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(
                'Could not save post: $error',
              ),
            ),
          );
        }
      }
    }

    title.dispose();
    caption.dispose();
    hashtags.dispose();
  }

  String _shareText(
    Map<String, dynamic> post,
  ) {
    return <String>[
      (post['caption'] ?? '').toString().trim(),
      (post['hashtags'] ?? '').toString().trim(),
    ].where((value) => value.isNotEmpty).join('\n\n');
  }

  Future<void> _postNow(
    Map<String, dynamic> post,
  ) async {
    final id = _id(post);
    if (id == null) return;

    try {
      final prepared = await _service.postNow(id);

      final text = (prepared['text'] ?? '').toString().trim();
      final effectiveText =
          text.isNotEmpty ? text : _shareText(post);

      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          text: effectiveText.isEmpty
              ? (post['title'] ?? 'Social media post')
                  .toString()
              : effectiveText,
          subject:
              (post['title'] ?? 'Social media post')
                  .toString(),
        ),
      );

      if (!mounted) return;

      final mark = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Was it posted?'),
          content: const Text(
            'If you completed the post in the selected social app, mark it as posted. Otherwise leave it Ready to Post.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                false,
              ),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                true,
              ),
              child: const Text('Mark posted'),
            ),
          ],
        ),
      );

      if (mark == true) {
        await _service.markPublished(id);
      }

      await _load();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not prepare the post: $error',
          ),
        ),
      );
    }
  }

  Future<void> _markPublished(
    Map<String, dynamic> post,
  ) async {
    final id = _id(post);
    if (id == null) return;

    await _service.markPublished(id);
    await _load();
  }

  void _toggle(int id) {
    setState(() {
      if (!_selected.add(id)) {
        _selected.remove(id);
      }
    });
  }

  void _selectAll() {
    final ids = _posts
        .map(_id)
        .whereType<int>()
        .toSet();

    setState(() {
      if (ids.isNotEmpty &&
          _selected.length == ids.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(ids);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty || _deleting) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete selected posts?',
        ),
        content: Text(
          '${_selected.length} post'
          '${_selected.length == 1 ? '' : 's'} '
          'will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _deleting = true);

    try {
      await _service.bulkDelete(
        _selected.toList(),
      );
      _selected.clear();
      await _load();
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  String _statusLabel(
    Map<String, dynamic> post,
  ) {
    final status =
        (post['status'] ?? 'draft').toString();

    if (status == 'ready_to_share') {
      return 'Ready to Post';
    }

    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                  '${word.substring(1)}',
        )
        .join(' ');
  }

  Color _statusColor(
    BuildContext context,
    String status,
  ) {
    switch (status) {
      case 'published':
        return const Color(0xFF047857);
      case 'ready_to_share':
        return const Color(0xFF0369A1);
      case 'scheduled':
        return const Color(0xFFB45309);
      default:
        return Theme.of(context)
            .colorScheme
            .onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _posts.isNotEmpty &&
        _selected.length ==
            _posts.map(_id).whereType<int>().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selected.length} selected'
              : 'Social Media Planner',
        ),
        leading: _selectionMode
            ? IconButton(
                onPressed: () {
                  setState(_selected.clear);
                },
                icon: const Icon(
                  Icons.close_rounded,
                ),
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: allSelected
                  ? 'Clear selection'
                  : 'Select all',
              onPressed: _selectAll,
              icon: Icon(
                allSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Delete selected',
              onPressed:
                  _deleting ? null : _deleteSelected,
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.delete_outline_rounded,
                    ),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Reports',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SocialMediaReportScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bar_chart_rounded),
            ),
            IconButton(
              tooltip: 'Social media accounts',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const SocialMediaAccountsScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.manage_accounts_outlined,
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _edit,
              icon: const Icon(Icons.add),
              label: const Text('New Post'),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            100,
          ),
          children: [
            if (_loading) ...[
              const LinearProgressIndicator(
                minHeight: 2,
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color:
                      const Color(0xFFBAE6FD),
                ),
              ),
              child: const Text(
                'Choose Automatic to post to all selected connected platforms from the Laravel scheduler. You receive reminders and posting-result notifications; any platform that cannot publish automatically falls back to Ready to Post.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: Color(0xFF075985),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Posts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_posts.isNotEmpty)
                  TextButton.icon(
                    onPressed: _selectAll,
                    icon: const Icon(
                      Icons.checklist_rounded,
                      size: 18,
                    ),
                    label: const Text('Select'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_loading && _posts.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(
                    Icons.campaign_outlined,
                  ),
                  title: Text(
                    'No social media posts yet',
                  ),
                  subtitle: Text(
                    'Create your first post and choose a schedule.',
                  ),
                ),
              )
            else
              ..._posts.map((post) {
                final id = _id(post);
                final selected =
                    id != null &&
                    _selected.contains(id);
                final status =
                    (post['status'] ?? 'draft')
                        .toString();
                final scheduled =
                    _date(post['scheduled_at']);

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding:
                          const EdgeInsets.all(2),
                      child: Column(
                        children: [
                          ListTile(
                            selected: selected,
                            leading: _selectionMode
                                ? Checkbox(
                                    value: selected,
                                    onChanged: id == null
                                        ? null
                                        : (_) =>
                                            _toggle(id),
                                  )
                                : const Icon(
                                    Icons
                                        .campaign_outlined,
                                  ),
                            title: Text(
                              (post['title'] ??
                                      'Untitled post')
                                  .toString(),
                            ),
                            subtitle: Text(
                              <String>[
                                _statusLabel(post),
                                if (scheduled != null)
                                  scheduled
                                      .toString()
                                      .substring(
                                        0,
                                        16,
                                      ),
                              ].join(' • '),
                              style: TextStyle(
                                color:
                                    _statusColor(
                                  context,
                                  status,
                                ),
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              if (_selectionMode &&
                                  id != null) {
                                _toggle(id);
                              } else {
                                _edit(post);
                              }
                            },
                            onLongPress:
                                id == null
                                    ? null
                                    : () =>
                                        _toggle(id),
                          ),
                          if (!_selectionMode)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .fromLTRB(
                                12,
                                0,
                                12,
                                10,
                              ),
                              child: Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _edit(post),
                                    icon: const Icon(
                                      Icons
                                          .edit_outlined,
                                      size: 17,
                                    ),
                                    label:
                                        const Text(
                                      'Edit',
                                    ),
                                  ),
                                  if (status !=
                                      'published') ...[
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _postNow(post),
                                      icon: const Icon(
                                        Icons
                                            .send_outlined,
                                        size: 17,
                                      ),
                                      label:
                                          const Text(
                                        'Post Now',
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip:
                                          'Mark posted',
                                      onPressed: () =>
                                          _markPublished(
                                            post,
                                          ),
                                      icon:
                                          const Icon(
                                        Icons
                                            .check_circle_outline,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
