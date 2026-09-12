import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/ai_form_assist_service.dart';

class SpiritualPracticesScreen extends StatefulWidget {
  const SpiritualPracticesScreen({super.key});

  @override
  State<SpiritualPracticesScreen> createState() =>
      _SpiritualPracticesScreenState();
}

class _SpiritualPracticesScreenState
    extends State<SpiritualPracticesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

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
      final response = await ApiClient.instance.get(
        'spiritual-practices',
        cacheable: false,
      );

      dynamic raw = response;

      if (raw is Map) {
        raw = raw['data'] ?? const [];
      }

      final items = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            items.add(Map<String, dynamic>.from(item));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _items = items;
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
        _error = 'Could not load spiritual practices.';
      });
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final title = TextEditingController(
      text: (existing?['practice_title'] ??
              existing?['title'] ??
              '')
          .toString(),
    );
    final type = TextEditingController(
      text: (existing?['practice_type'] ?? '').toString(),
    );
    final faith = TextEditingController(
      text: (existing?['faith_path'] ?? '').toString(),
    );
    final inspiration = TextEditingController(
      text: (existing?['inspirational_text'] ??
              existing?['scriptures'] ??
              '')
          .toString(),
    );
    final source = TextEditingController(
      text: (existing?['source_tradition'] ?? '').toString(),
    );
    final reflection = TextEditingController(
      text: (existing?['reflection'] ?? '').toString(),
    );
    final gratitude = TextEditingController(
      text: (existing?['gratitude'] ?? '').toString(),
    );
    final intention = TextEditingController(
      text: (existing?['intention'] ?? '').toString(),
    );
    final place = TextEditingController(
      text: (existing?['community_place'] ?? '').toString(),
    );
    final notes = TextEditingController(
      text: (existing?['notes'] ?? '').toString(),
    );
    final duration = TextEditingController(
      text: '${existing?['duration_minutes'] ?? ''}',
    );

    DateTime practicedAt = DateTime.tryParse(
          (existing?['practiced_at'] ?? '').toString(),
        )?.toLocal() ??
        DateTime.now();

    String? formError;
    bool saving = false;
    bool aiLoading = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .88,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        existing == null
                            ? 'New Spiritual Practice'
                            : 'Edit Spiritual Practice',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    children: [
                      TextField(
                        controller: title,
                        onChanged: (_) => setLocal(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Practice title / topic',
                          hintText: 'Gratitude, patience, morning reflection...',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: type.text.trim().isEmpty
                            ? null
                            : type.text.trim(),
                        decoration: const InputDecoration(
                          labelText: 'Practice type *',
                        ),
                        hint: const Text('Select practice type'),
                        items: const [
                          DropdownMenuItem(value:'prayer',child:Text('Prayer')),
                          DropdownMenuItem(value:'meditation',child:Text('Meditation')),
                          DropdownMenuItem(value:'worship',child:Text('Worship')),
                          DropdownMenuItem(value:'sacred_text_reading',child:Text('Sacred / inspirational text reading')),
                          DropdownMenuItem(value:'reflection',child:Text('Reflection')),
                          DropdownMenuItem(value:'gratitude',child:Text('Gratitude')),
                          DropdownMenuItem(value:'fasting',child:Text('Fasting')),
                          DropdownMenuItem(value:'mindfulness',child:Text('Mindfulness')),
                          DropdownMenuItem(value:'community_gathering',child:Text('Community gathering')),
                          DropdownMenuItem(value:'service',child:Text('Service / charity')),
                          DropdownMenuItem(value:'chanting',child:Text('Chanting')),
                          DropdownMenuItem(value:'pilgrimage',child:Text('Pilgrimage')),
                          DropdownMenuItem(value:'study',child:Text('Study')),
                          DropdownMenuItem(value:'personal_ritual',child:Text('Personal ritual')),
                          DropdownMenuItem(value:'other',child:Text('Other')),
                        ],
                        onChanged: (value) => setLocal(() {
                          type.text = value ?? '';
                        }),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF4FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF0ABFC)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'AI Generate',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add a practice title/topic or choose a practice type above. AI prepares an editable draft based on your selected faith or spiritual path.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: aiLoading ||
                                      (title.text.trim().isEmpty &&
                                          type.text.trim().isEmpty)
                                  ? null
                                  : () async {
                                      final topic = title.text.trim().isNotEmpty
                                          ? title.text.trim()
                                          : type.text.trim();

                                      setLocal(() {
                                        aiLoading = true;
                                        formError = null;
                                      });

                                      try {
                                        final draft =
                                            await const AiFormAssistService()
                                                .generate(
                                          module: 'spiritual-practices',
                                          topic: topic,
                                          context: <String, dynamic>{
                                            if (faith.text.trim().isNotEmpty)
                                              'faith_path': faith.text.trim(),
                                            if (type.text.trim().isNotEmpty)
                                              'practice_type': type.text.trim(),
                                          },
                                        );

                                        void fill(
                                          TextEditingController controller,
                                          String key,
                                        ) {
                                          if (controller.text.trim().isEmpty &&
                                              draft[key] != null) {
                                            controller.text =
                                                draft[key].toString();
                                          }
                                        }

                                        fill(title, 'practice_title');
                                        fill(type, 'practice_type');
                                        fill(inspiration, 'inspirational_text');
                                        fill(source, 'source_tradition');
                                        if (source.text.trim().isEmpty &&
                                            draft['source_reference'] != null) {
                                          source.text =
                                              draft['source_reference']
                                                  .toString();
                                        }
                                        fill(reflection, 'reflection');
                                        fill(gratitude, 'gratitude');
                                        fill(intention, 'intention');
                                        fill(duration, 'duration_minutes');
                                        fill(notes, 'notes');

                                        setLocal(() {
                                          formError =
                                              'AI draft ready. Review and edit it before saving.';
                                        });
                                      } on ApiException catch (e) {
                                        setLocal(() => formError = e.message);
                                      } catch (_) {
                                        setLocal(() {
                                          formError =
                                              'AI could not prepare a draft. Your form was kept.';
                                        });
                                      } finally {
                                        setLocal(() => aiLoading = false);
                                      }
                                    },
                              icon: aiLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome_outlined),
                              label: Text(
                                aiLoading ? 'Generating...' : 'AI Generate',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: title,
                        decoration: const InputDecoration(
                          labelText: 'Practice title',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: type,
                        decoration: const InputDecoration(
                          labelText: 'Practice type',
                          hintText: 'Prayer, reflection, worship...',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: faith,
                        decoration: const InputDecoration(
                          labelText: 'Faith / spiritual path',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Practice date'),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy').format(practicedAt),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: practicedAt,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setLocal(() => practicedAt = picked);
                          }
                        },
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
                        controller: inspiration,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Sacred / inspirational text',
                          alignLabelWithHint: true,
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
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Reflection',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: gratitude,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Gratitude',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: intention,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Intention',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: place,
                        decoration: const InputDecoration(
                          labelText: 'Community / place',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notes,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          formError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          if (type.text.trim().isEmpty) {
                            setLocal(
                              () => formError = 'Practice type is required.',
                            );
                            return;
                          }

                          setLocal(() {
                            saving = true;
                            formError = null;
                          });

                          if (type.text.trim().isEmpty) {
                            setLocal(() {
                              saving = false;
                              formError = 'Select a practice type.';
                            });
                            return;
                          }

                          final body = <String, dynamic>{
                            'practice_title': title.text.trim().isEmpty
                                ? null
                                : title.text.trim(),
                            'practice_type': type.text.trim(),
                            'faith_path': faith.text.trim().isEmpty
                                ? null
                                : faith.text.trim(),
                            'practiced_at':
                                practicedAt.toIso8601String(),
                            'duration_minutes':
                                int.tryParse(duration.text.trim()),
                            'inspirational_text':
                                inspiration.text.trim().isEmpty
                                    ? null
                                    : inspiration.text.trim(),
                            'source_tradition':
                                source.text.trim().isEmpty
                                    ? null
                                    : source.text.trim(),
                            'reflection': reflection.text.trim().isEmpty
                                ? null
                                : reflection.text.trim(),
                            'gratitude': gratitude.text.trim().isEmpty
                                ? null
                                : gratitude.text.trim(),
                            'intention': intention.text.trim().isEmpty
                                ? null
                                : intention.text.trim(),
                            'community_place':
                                place.text.trim().isEmpty
                                    ? null
                                    : place.text.trim(),
                            'notes': notes.text.trim().isEmpty
                                ? null
                                : notes.text.trim(),
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
                          } on ApiException catch (error) {
                            setLocal(() {
                              saving = false;
                              formError = error.message;
                            });
                          } catch (_) {
                            setLocal(() {
                              saving = false;
                              formError =
                                  'Could not save the spiritual practice.';
                            });
                          }
                        },
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    title.dispose();
    type.dispose();
    faith.dispose();
    inspiration.dispose();
    source.dispose();
    reflection.dispose();
    gratitude.dispose();
    intention.dispose();
    place.dispose();
    notes.dispose();
    duration.dispose();

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete practice?'),
        content: const Text(
          'This will remove the spiritual practice from your active records.',
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
      ),
    );

    if (yes != true) return;

    try {
      await ApiClient.instance.delete('spiritual-practices/$id');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  String _title(Map<String, dynamic> item) {
    return (item['practice_title'] ??
            item['title'] ??
            item['practice_type'] ??
            'Spiritual Practice')
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spiritual Practice'),
        actions: [
          IconButton(
            onPressed: _load,
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
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            const Text(
              'Your spiritual practices',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Review reflections, gratitude, intentions and practices you have recorded.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _items.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('Could not load spiritual practices'),
                  subtitle: Text(_error!),
                  trailing: const Icon(Icons.refresh),
                  onTap: _load,
                ),
              )
            else if (_items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No spiritual practices yet. Tap Add Practice to create your first record.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._items.map(
                (item) {
                  final date = DateTime.tryParse(
                    (item['practiced_at'] ?? '').toString(),
                  )?.toLocal();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 11),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(
                        16,
                        10,
                        8,
                        10,
                      ),
                      leading: const CircleAvatar(
                        child: Icon(Icons.self_improvement),
                      ),
                      title: Text(
                        _title(item),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 3),
                          Text(
                            [
                              if ((item['faith_path'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                item['faith_path'].toString(),
                              if (date != null)
                                DateFormat('dd MMM yyyy').format(date),
                              if (item['duration_minutes'] != null)
                                '${item['duration_minutes']} min',
                            ].join(' · '),
                          ),
                          if ((item['reflection'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item['reflection'].toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openForm(item);
                          if (value == 'delete') _delete(item);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                      onTap: () => _openForm(item),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
