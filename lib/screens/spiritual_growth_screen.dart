import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/ai_form_assist_service.dart';
import '../services/scripture_reference_service.dart';

class SpiritualGrowthScreen extends StatefulWidget {
  const SpiritualGrowthScreen({super.key});

  @override
  State<SpiritualGrowthScreen> createState() =>
      _SpiritualGrowthScreenState();
}

class _SpiritualGrowthScreenState extends State<SpiritualGrowthScreen> {
  static const List<String> _faithPaths = <String>[
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

  static const List<String> _practiceTypes = <String>[
    'Prayer',
    'Meditation',
    'Worship',
    'Sacred text reading',
    'Reflection',
    'Gratitude',
    'Fasting',
    'Mindfulness',
    'Community gathering',
    'Service / charity',
    'Chanting',
    'Pilgrimage',
    'Study',
    'Personal ritual',
    'Other',
  ];

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

      if (response is Map && response['data'] != null) {
        response = response['data'];
      }
      if (response is Map && response['data'] is List) {
        response = response['data'];
      }

      final rows = response is List
          ? response
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _items = rows;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Could not load Spiritual Growth right now.';
      });
    }
  }

  bool _hasText(dynamic value) {
    return value != null && value.toString().trim().isNotEmpty;
  }

  DateTime _parsePracticeDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toLocal() ?? DateTime.now();
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    String? faith = existing?['faith_path']?.toString();
    if (faith != null && !_faithPaths.contains(faith)) {
      faith = 'Custom';
    }

    String practice = existing?['practice_type']?.toString() ?? 'Reflection';
    if (!_practiceTypes.contains(practice)) {
      practice = 'Other';
    }

    DateTime practiceDate = _parsePracticeDate(existing?['practice_date']);

    final customFaith = TextEditingController(
      text: existing?['custom_faith_path']?.toString() ?? '',
    );
    final title = TextEditingController(
      text: existing?['practice_title']?.toString() ?? '',
    );
    final theme = TextEditingController(
      text: existing?['theme_topic']?.toString() ?? '',
    );
    final duration = TextEditingController(
      text: existing?['duration_minutes']?.toString() ?? '',
    );
    final inspirationalText = TextEditingController(
      text: existing?['inspirational_text']?.toString() ?? '',
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
    final notes = TextEditingController(
      text: existing?['notes']?.toString() ?? '',
    );

    bool saving = false;
    String? formError;
    List<ScriptureReference> bibleRefs = <ScriptureReference>[];
    String? refsMessage;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.60,
            maxChildSize: 0.97,
            expand: false,
            builder: (context, scrollController) {
              return Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                clipBehavior: Clip.antiAlias,
                child: StatefulBuilder(
                  builder: (context, setLocal) {
                    Future<void> generateAi() async {
                      final topic = theme.text.trim().isNotEmpty
                          ? theme.text.trim()
                          : title.text.trim();

                      if (topic.isEmpty) {
                        setLocal(() {
                          formError =
                              'Enter a theme/topic or practice title first.';
                        });
                        return;
                      }

                      try {
                        final draft = await const AiFormAssistService().generate(
                          module: 'spiritual-practices',
                          topic: topic,
                          context: <String, dynamic>{
                            if ((faith ?? '').isNotEmpty) 'faith_path': faith,
                            'practice_type': practice,
                          },
                        );

                        if ((draft['practice_title'] ?? '').toString().trim().isNotEmpty) {
                          title.text = draft['practice_title'].toString();
                        }
                        if ((draft['theme_topic'] ?? '').toString().trim().isNotEmpty) {
                          theme.text = draft['theme_topic'].toString();
                        }
                        if ((draft['inspirational_text'] ?? '').toString().trim().isNotEmpty) {
                          inspirationalText.text =
                              draft['inspirational_text'].toString();
                        }
                        if ((draft['source_tradition'] ?? '').toString().trim().isNotEmpty) {
                          source.text = draft['source_tradition'].toString();
                        }
                        if ((draft['reflection'] ?? '').toString().trim().isNotEmpty) {
                          reflection.text = draft['reflection'].toString();
                        }
                        if ((draft['gratitude'] ?? '').toString().trim().isNotEmpty) {
                          gratitude.text = draft['gratitude'].toString();
                        }
                        if ((draft['intention'] ?? '').toString().trim().isNotEmpty) {
                          intention.text = draft['intention'].toString();
                        }

                        // For Christianity, also suggest Bible references
                        // for the same topic so the draft includes them.
                        final effectiveFaith = (faith ?? '').trim();
                        if (effectiveFaith.toLowerCase().contains('christ')) {
                          final refs =
                              const ScriptureReferenceService().forTopic(
                            theme.text.trim().isNotEmpty
                                ? theme.text.trim()
                                : title.text.trim(),
                            faithPath: effectiveFaith,
                          );
                          if (refs.isNotEmpty) {
                            bibleRefs = refs;
                            refsMessage =
                                'Added ${refs.length} Bible references below. Tap Insert to add them to the sacred text field.';
                          }
                        }

                        setLocal(() {
                          formError =
                              'AI draft ready. Review and edit before saving.';
                        });
                      } on ApiException catch (error) {
                        setLocal(() => formError = error.message);
                      } catch (_) {
                        setLocal(() {
                          formError =
                              'AI could not generate the spiritual growth draft.';
                        });
                      }
                    }

                    void fetchBibleRefs() {
                      final topic = theme.text.trim().isNotEmpty
                          ? theme.text.trim()
                          : title.text.trim();
                      if (topic.isEmpty) {
                        setLocal(() {
                          refsMessage =
                              'Enter a theme/topic or practice title first.';
                        });
                        return;
                      }
                      final refs =
                          const ScriptureReferenceService().forTopic(
                        topic,
                        faithPath: (faith ?? '').trim(),
                      );
                      setLocal(() {
                        bibleRefs = refs;
                        refsMessage = refs.isEmpty
                            ? 'Bible references are available for Christianity.'
                            : 'Found ${refs.length} Bible references for "$topic".';
                      });
                    }

                    void insertBibleRefs() {
                      if (bibleRefs.isEmpty) return;
                      final formatted = bibleRefs
                          .map((ref) => ref.formatted)
                          .join('\n');
                      final current = inspirationalText.text.trim();
                      setLocal(() {
                        inspirationalText.text = current.isEmpty
                            ? formatted
                            : '$current\n\n$formatted';
                        refsMessage = 'Bible references added to sacred text.';
                      });
                    }

                    Future<void> pickDate() async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: practiceDate,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );

                      if (picked != null) {
                        setLocal(() {
                          practiceDate = picked;
                        });
                      }
                    }

                    Future<void> save() async {
                      setLocal(() {
                        saving = true;
                        formError = null;
                      });

                      final body = <String, dynamic>{
                        'faith_path': faith,
                        'custom_faith_path': faith == 'Custom'
                            ? customFaith.text.trim()
                            : null,
                        'practice_type': practice,
                        'practice_title': title.text.trim(),
                        'theme_topic': theme.text.trim(),
                        'practice_date': DateFormat('yyyy-MM-dd').format(practiceDate),
                        'duration_minutes': int.tryParse(duration.text.trim()),
                        'inspirational_text': inspirationalText.text.trim(),
                        'source_tradition': source.text.trim(),
                        'reflection': reflection.text.trim(),
                        'gratitude': gratitude.text.trim(),
                        'intention': intention.text.trim(),
                        'community_place': place.text.trim(),
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

                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      } on ApiException catch (error) {
                        if (context.mounted) {
                          setLocal(() {
                            saving = false;
                            formError = error.message;
                          });
                        }
                      } catch (_) {
                        if (context.mounted) {
                          setLocal(() {
                            saving = false;
                            formError = 'The spiritual practice could not be saved.';
                          });
                        }
                      }
                    }

                    return Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 52,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF475569),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              20,
                              18,
                              20,
                              MediaQuery.viewInsetsOf(context).bottom + 28,
                            ),
                            children: [
                              Text(
                                existing == null
                                    ? 'Add Spiritual Growth'
                                    : 'Edit Spiritual Growth',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Use the fields that are meaningful to your own religion, tradition or personal reflection practice.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: generateAi,
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: const Text('AI Generate'),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: faith,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Faith / spiritual path',
                                ),
                                selectedItemBuilder: (context) {
                                  return _faithPaths
                                      .map(
                                        (value) => Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            value,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(growable: false);
                                },
                                items: _faithPaths
                                    .map(
                                      (value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: saving
                                    ? null
                                    : (value) {
                                        setLocal(() {
                                          faith = value;
                                        });
                                      },
                              ),
                              if (faith == 'Custom') ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: customFaith,
                                  decoration: const InputDecoration(
                                    labelText: 'Custom faith / path',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: practice,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Practice type',
                                ),
                                items: _practiceTypes
                                    .map(
                                      (value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: saving
                                    ? null
                                    : (value) {
                                        setLocal(() {
                                          practice = value ?? 'Reflection';
                                        });
                                      },
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: title,
                                decoration: const InputDecoration(
                                  labelText: 'Practice title',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: theme,
                                decoration: const InputDecoration(
                                  labelText: 'Theme / topic',
                                ),
                              ),
                              if ((faith ?? '')
                                  .toLowerCase()
                                  .contains('christ')) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: saving ? null : fetchBibleRefs,
                                  icon: const Icon(
                                    Icons.menu_book_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Fetch Bible references (3-5)',
                                  ),
                                ),
                                if (refsMessage != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    refsMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (bibleRefs.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (final ref in bibleRefs)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: Text(
                                              ref.formatted,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        FilledButton.tonalIcon(
                                          onPressed:
                                              saving ? null : insertBibleRefs,
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Insert into sacred text',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                              const SizedBox(height: 14),
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                title: const Text('Practice date'),
                                subtitle: Text(
                                  DateFormat('dd MMM yyyy').format(practiceDate),
                                ),
                                trailing: const Icon(
                                  Icons.calendar_month_outlined,
                                ),
                                onTap: saving ? null : pickDate,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: duration,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Duration (minutes)',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: inspirationalText,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Sacred / inspirational text',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: source,
                                decoration: const InputDecoration(
                                  labelText: 'Source / tradition',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: reflection,
                                minLines: 3,
                                maxLines: 6,
                                decoration: const InputDecoration(
                                  labelText: 'Reflection',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: gratitude,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Gratitude',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: intention,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Intention',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: place,
                                decoration: const InputDecoration(
                                  labelText: 'Community / place',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: notes,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Notes',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              if (formError != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  formError!,
                                  style: const TextStyle(
                                    color: Color(0xFFBE123C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
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
                      ],
                    );
                  },
                ),
              );
            },
          );
        },
      );

      if (saved == true) {
        await _load();
      }
    } finally {
      customFaith.dispose();
      title.dispose();
      theme.dispose();
      duration.dispose();
      inspirationalText.dispose();
      source.dispose();
      reflection.dispose();
      gratitude.dispose();
      intention.dispose();
      place.dispose();
      notes.dispose();
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete spiritual practice?'),
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

    if (confirmed != true) {
      return;
    }

    try {
      await ApiClient.instance.delete('spiritual-practices/$id');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.self_improvement_rounded,
          size: 58,
        ),
        const SizedBox(height: 14),
        const Text(
          'No spiritual growth entries yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Record a prayer, meditation, reflection, sacred reading, gratitude practice or another meaningful practice.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: _openForm,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Spiritual Growth'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spiritual Growth'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null && _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      const Icon(Icons.error_outline_rounded, size: 52),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final practiceTitle = _hasText(item['practice_title'])
                              ? item['practice_title'].toString()
                              : _hasText(item['practice_type'])
                                  ? item['practice_type'].toString()
                                  : 'Reflection';

                          final details = <dynamic>[
                            item['faith_path'],
                            item['practice_date'],
                            item['reflection'],
                          ]
                              .where(_hasText)
                              .map((value) => value.toString())
                              .take(2)
                              .join(' · ');

                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.self_improvement_rounded),
                              ),
                              title: Text(
                                practiceTitle,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: details.isEmpty
                                  ? null
                                  : Text(
                                      details,
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
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Edit'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.delete_outline_rounded),
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
