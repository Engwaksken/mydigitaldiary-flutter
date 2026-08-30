import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';

class SpiritualGrowthScreen extends StatefulWidget {
  const SpiritualGrowthScreen({super.key});

  @override
  State<SpiritualGrowthScreen> createState() => _SpiritualGrowthScreenState();
}

class _SpiritualGrowthScreenState extends State<SpiritualGrowthScreen> {
  static const List<String> faithPaths = [
    'Christianity',
    'Islam',
    'Judaism',
    'Hinduism',
    'Buddhism',
    'Sikhism',
    'Baháʼí Faith',
    'African Traditional / Indigenous Spirituality',
    'Other religion',
    'Spiritual but not religious',
    'Secular reflection',
    'Prefer not to specify',
    'Custom',
  ];

  static const Map<String, String> practiceTypes = {
    'prayer': 'Prayer',
    'meditation': 'Meditation',
    'worship': 'Worship',
    'sacred_text_reading': 'Sacred / Inspirational Text Reading',
    'reflection': 'Reflection',
    'gratitude': 'Gratitude',
    'fasting': 'Fasting',
    'mindfulness': 'Mindfulness',
    'community_gathering': 'Community Gathering',
    'service': 'Service / Charity',
    'chanting': 'Chanting',
    'pilgrimage': 'Pilgrimage',
    'study': 'Study',
    'personal_ritual': 'Personal Ritual',
    'other': 'Other',
  };

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      dynamic response = await ApiClient.instance.get(
        'spiritual-practices',
        cacheable: false,
      );

      if (response is Map && response['data'] is List) {
        response = response['data'];
      } else if (response is Map &&
          response['data'] is Map &&
          response['data']['data'] is List) {
        response = response['data']['data'];
      }

      final items = (response is List ? response : const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load Spiritual Growth right now.';
      });
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    String faith = _normaliseFaith(existing?['faith_path']);
    String practice = _normalisePractice(existing?['practice_type']);
    String recurrence =
        existing?['recurrence_frequency']?.toString() ?? '';

    DateTime practicedAt =
        _parseDate(existing?['practiced_at']) ?? DateTime.now();
    DateTime? recurrenceEndsAt =
        _parseDate(existing?['recurrence_ends_at']);

    final customFaith = TextEditingController(
      text: existing?['custom_faith_path']?.toString() ?? '',
    );
    final title = TextEditingController(
      text: (existing?['practice_title'] ??
              existing?['title'] ??
              '')
          .toString(),
    );
    final theme = TextEditingController(
      text: existing?['theme_topic']?.toString() ?? '',
    );
    final inspirational = TextEditingController(
      text: (existing?['inspirational_text'] ??
              existing?['scriptures'] ??
              '')
          .toString(),
    );
    final source = TextEditingController(
      text: existing?['source_tradition']?.toString() ?? '',
    );
    final reflection = TextEditingController(
      text: existing?['reflection']?.toString() ?? '',
    );
    final gratitude = TextEditingController(
      text: existing?['gratitude']?.toString() ?? '',
    );
    final intention = TextEditingController(
      text: existing?['intention']?.toString() ?? '',
    );
    final place = TextEditingController(
      text: existing?['community_place']?.toString() ?? '',
    );
    final duration = TextEditingController(
      text: existing?['duration_minutes']?.toString() ?? '',
    );
    final repeatDays = TextEditingController(
      text: _daysText(existing?['recurrence_days_of_week']),
    );
    final notes = TextEditingController(
      text: existing?['notes']?.toString() ?? '',
    );

    bool saving = false;
    String? formError;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setLocal) {
            Future<void> pickPracticeDate() async {
              final value = await showDatePicker(
                context: sheetContext,
                initialDate: practicedAt,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(
                  const Duration(days: 3650),
                ),
              );
              if (value != null) {
                setLocal(() {
                  practicedAt = value;
                  if (recurrenceEndsAt != null &&
                      recurrenceEndsAt!.isBefore(practicedAt)) {
                    recurrenceEndsAt = practicedAt;
                  }
                });
              }
            }

            Future<void> pickRecurrenceEnd() async {
              final value = await showDatePicker(
                context: sheetContext,
                initialDate: recurrenceEndsAt ?? practicedAt,
                firstDate: practicedAt,
                lastDate: DateTime.now().add(
                  const Duration(days: 3650),
                ),
              );
              if (value != null) {
                setLocal(() => recurrenceEndsAt = value);
              }
            }

            Future<void> save() async {
              setLocal(() {
                saving = true;
                formError = null;
              });

              final body = <String, dynamic>{
                'faith_path': faith == 'Prefer not to specify' ? null : faith,
                'custom_faith_path':
                    faith == 'Custom' ? customFaith.text.trim() : null,
                'practice_type': practice,
                'practice_title': title.text.trim(),
                'theme_topic': theme.text.trim(),
                'practiced_at': _apiDate(practicedAt),
                'duration_minutes': int.tryParse(duration.text.trim()),
                'inspirational_text': inspirational.text.trim(),
                'source_tradition': source.text.trim(),
                'reflection': reflection.text.trim(),
                'gratitude': gratitude.text.trim(),
                'intention': intention.text.trim(),
                'community_place': place.text.trim(),
                'recurrence_frequency':
                    recurrence.isEmpty ? null : recurrence,
                'recurrence_days_of_week':
                    recurrence == 'weekly'
                        ? _parseDays(repeatDays.text)
                        : null,
                'recurrence_ends_at':
                    recurrence.isEmpty || recurrenceEndsAt == null
                        ? null
                        : _apiDate(recurrenceEndsAt!),
                'notes': notes.text.trim(),
              };

              try {
                if (existing == null) {
                  await ApiClient.instance.post(
                    'spiritual-practices',
                    body,
                  );
                } else {
                  await ApiClient.instance.put(
                    'spiritual-practices/${existing['id']}',
                    body,
                  );
                }

                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, true);
                }
              } on ApiException catch (e) {
                if (sheetContext.mounted) {
                  setLocal(() {
                    formError = e.message;
                    saving = false;
                  });
                }
              } catch (_) {
                if (sheetContext.mounted) {
                  setLocal(() {
                    formError =
                        'Could not save this spiritual growth entry.';
                    saving = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 4,
                bottom:
                    MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? 'Add Spiritual Growth'
                          : 'Edit Spiritual Growth',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Use the fields that are meaningful to your own religion, tradition or personal reflection practice.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: faith,
                      decoration: const InputDecoration(
                        labelText: 'Faith / spiritual path',
                      ),
                      items: faithPaths
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              setLocal(() {
                                faith =
                                    value ?? 'Prefer not to specify';
                              });
                            },
                    ),
                    if (faith == 'Custom') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: customFaith,
                        decoration: const InputDecoration(
                          labelText: 'Custom faith / path',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: practice,
                      decoration: const InputDecoration(
                        labelText: 'Practice type',
                      ),
                      items: practiceTypes.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              setLocal(() {
                                practice = value ?? 'reflection';
                              });
                            },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Practice title',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: theme,
                      decoration: const InputDecoration(
                        labelText: 'Theme / topic',
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Practice date'),
                      subtitle:
                          Text(DateFormat('d MMM yyyy').format(practicedAt)),
                      trailing:
                          const Icon(Icons.calendar_today_outlined),
                      onTap: saving ? null : pickPracticeDate,
                    ),
                    TextField(
                      controller: duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: inspirational,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Sacred / inspirational text',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: source,
                      decoration: const InputDecoration(
                        labelText: 'Source / tradition',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reflection,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Reflection',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: gratitude,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Gratitude',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: intention,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Intention',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: place,
                      decoration: const InputDecoration(
                        labelText: 'Community / place',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: recurrence,
                      decoration: const InputDecoration(
                        labelText: 'Repeat',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '',
                          child: Text('Does not repeat'),
                        ),
                        DropdownMenuItem(
                          value: 'daily',
                          child: Text('Daily'),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              setLocal(() {
                                recurrence = value ?? '';
                                if (recurrence.isEmpty) {
                                  recurrenceEndsAt = null;
                                }
                              });
                            },
                    ),
                    if (recurrence == 'weekly') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: repeatDays,
                        decoration: const InputDecoration(
                          labelText: 'Repeat on',
                          hintText: '1,3,5 = Mon, Wed, Fri',
                        ),
                      ),
                    ],
                    if (recurrence.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Repeat until'),
                        subtitle: Text(
                          recurrenceEndsAt == null
                              ? 'No end date'
                              : DateFormat('d MMM yyyy')
                                  .format(recurrenceEndsAt!),
                        ),
                        trailing:
                            const Icon(Icons.event_repeat_outlined),
                        onTap: saving ? null : pickRecurrenceEnd,
                      ),
                    ],
                    TextField(
                      controller: notes,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Notes'),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        formError!,
                        style: const TextStyle(
                          color: Color(0xFFBE123C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: saving ? null : save,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(saving ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    for (final controller in <TextEditingController>[
      customFaith,
      title,
      theme,
      inspirational,
      source,
      reflection,
      gratitude,
      intention,
      place,
      duration,
      repeatDays,
      notes,
    ]) {
      controller.dispose();
    }

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete spiritual growth entry?'),
          content: const Text(
            'This entry will be removed from your Spiritual Growth history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiClient.instance.delete(
        'spiritual-practices/${item['id']}',
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  String _normaliseFaith(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return faithPaths.contains(text)
        ? text
        : 'Prefer not to specify';
  }

  String _normalisePractice(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (practiceTypes.containsKey(text)) return text;

    final normalised = text
        .replaceAll('/', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), '_');

    return practiceTypes.containsKey(normalised)
        ? normalised
        : 'reflection';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _apiDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  List<int> _parseDays(String value) {
    final values = value
        .split(RegExp(r'[\s,]+'))
        .map(int.tryParse)
        .whereType<int>()
        .where((day) => day >= 1 && day <= 7)
        .toSet()
        .toList()
      ..sort();

    return values;
  }

  String _daysText(dynamic value) {
    if (value is List) return value.join(',');
    return value?.toString() ?? '';
  }

  String _displayDate(dynamic item) {
    final raw = item?['practiced_at'] ?? item?['created_at'];
    final parsed = _parseDate(raw);
    if (parsed == null) return '';
    return DateFormat('d MMM yyyy').format(parsed);
  }

  String _displayTitle(Map<String, dynamic> item) {
    final title =
        (item['practice_title'] ?? item['title'] ?? '').toString().trim();

    if (title.isNotEmpty) return title;

    final key =
        item['practice_type']?.toString().toLowerCase() ?? 'reflection';
    return practiceTypes[key] ?? 'Reflection';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spiritual Growth'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Practice'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null && _items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      const SizedBox(height: 100),
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 46,
                        color: Color(0xFFBE123C),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(18),
                        children: const [
                          SizedBox(height: 120),
                          Icon(
                            Icons.self_improvement_rounded,
                            size: 50,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No spiritual growth entries yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Record prayer, meditation, reflection, gratitude, worship, mindfulness or another practice meaningful to you.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          12,
                          12,
                          12,
                          90,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final faith =
                              item['faith_path']?.toString().trim() ?? '';
                          final date = _displayDate(item);
                          final reflection =
                              item['reflection']?.toString().trim() ?? '';

                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(
                                  Icons.self_improvement_rounded,
                                ),
                              ),
                              title: Text(
                                _displayTitle(item),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                <String>[
                                  if (faith.isNotEmpty) faith,
                                  if (date.isNotEmpty) date,
                                  if (reflection.isNotEmpty) reflection,
                                ].take(2).join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _openForm(item),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _openForm(item);
                                  } else if (value == 'delete') {
                                    _delete(item);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading:
                                          Icon(Icons.edit_outlined),
                                      title: Text('Edit'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading:
                                          Icon(Icons.delete_outline),
                                      title: Text('Delete'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
