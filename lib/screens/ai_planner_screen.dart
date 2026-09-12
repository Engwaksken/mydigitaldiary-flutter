import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';

class AiPlannerScreen extends StatefulWidget {
  const AiPlannerScreen({super.key});

  @override
  State<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends State<AiPlannerScreen> {
  final TextEditingController _prompt = TextEditingController();
  bool _loading = true;
  bool _generating = false;
  String? _error;
  List<Map<String, dynamic>> _plans = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
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
        'ai-plans',
        cacheable: false,
      );

      dynamic raw = response;
      if (raw is Map) {
        raw = raw['data'] ?? const [];
      }

      final plans = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            plans.add(Map<String, dynamic>.from(item));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _plans = plans;
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
        _error = 'Could not load your AI plans.';
      });
    }
  }

  Future<void> _generate() async {
    if (_generating) return;

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      await ApiClient.instance.post(
        'ai-plans',
        <String, dynamic>{
          'custom_prompt': _prompt.text.trim().isEmpty
              ? null
              : _prompt.text.trim(),
          'client_datetime': DateTime.now().toIso8601String(),
        },
      );

      _prompt.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not generate the plan.');
      }
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _view(Map<String, dynamic> summary) async {
    Map<String, dynamic> plan = summary;

    try {
      final id = summary['id'];
      if (id != null) {
        final response = await ApiClient.instance.get(
          'ai-plans/$id',
          cacheable: false,
        );
        if (response is Map && response['data'] is Map) {
          plan = Map<String, dynamic>.from(response['data'] as Map);
        }
      }
    } catch (_) {
      // The history item already carries content, so viewing still works
      // if the dedicated show endpoint is temporarily unavailable.
    }

    if (!mounted) return;

    final content = (plan['content'] ?? '').toString().trim();
    final prompt = (plan['custom_prompt'] ?? '').toString().trim();
    final created = DateTime.tryParse(
      (plan['created_at'] ?? '').toString(),
    )?.toLocal();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Saved AI Plan',
                      style: TextStyle(
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
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (created != null)
                      Text(
                        DateFormat('dd MMM yyyy, h:mm a').format(created),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (prompt.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Your request',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(prompt),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Plan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      content.isEmpty ? 'No plan content available.' : content,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> plan) async {
    final id = plan['id'];
    if (id == null) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete plan?'),
        content: const Text(
          'This removes the saved AI plan from your history.',
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

    await ApiClient.instance.delete('ai-plans/$id');
    await _load();
  }

  String _preview(Map<String, dynamic> plan) {
    final content = (plan['content'] ?? '').toString().trim();
    if (content.length <= 190) return content;
    return '${content.substring(0, 190)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Planner'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _prompt,
              maxLength: 3000,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'What should the AI Planner generate?',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _generating ? 'Generating...' : 'Generate New Plan',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Saved Plans',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_plans.length}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading && _plans.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_plans.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Text(
                    'No saved plans yet. Generate your first plan above.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._plans.map(
                (plan) {
                  final created = DateTime.tryParse(
                    (plan['created_at'] ?? '').toString(),
                  )?.toLocal();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  created == null
                                      ? 'Saved Plan'
                                      : DateFormat(
                                          'dd MMM yyyy, h:mm a',
                                        ).format(created),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'View',
                                onPressed: () => _view(plan),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(plan),
                                icon: const Icon(
                                  Icons.delete_outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _preview(plan),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              height: 1.45,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _view(plan),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('View Full Plan'),
                          ),
                        ],
                      ),
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
