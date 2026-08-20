import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ai_plan.dart';
import '../services/ai_plan_service.dart';
import '../services/api_client.dart';
import '../widgets/confirm_action_dialog.dart';

class AiPlannerScreen extends StatefulWidget {
  const AiPlannerScreen({super.key});

  @override
  State<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends State<AiPlannerScreen> {
  final _service = AiPlanService();
  List<AiPlan> _plans = [];
  bool _loading = true;
  bool _generating = false;
  final _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _promptController.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final plans = await _service.list();
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await _service.generate(customPrompt: _promptController.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New plan generated.')));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _delete(AiPlan plan) async {
    final confirmed = await showAppConfirmDialog(context, title: 'Delete this plan?', message: 'This AI plan will be permanently deleted. This action cannot be undone.', confirmText: 'Delete plan');
    if (!confirmed) return;

    try {
      await _service.delete(plan.id);
      setState(() => _plans.removeWhere((p) => p.id == plan.id));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _viewPlan(AiPlan plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AiPlanViewerScreen(
          plan: plan,
          onDownloadPdf: () => _downloadPdf(plan),
        ),
      ),
    );
  }

  Future<void> _downloadPdf(AiPlan plan) async {
    if (plan.pdfUrl.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF is not available for this plan.')),
        );
      }
      return;
    }

    final uri = Uri.parse(plan.pdfUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the PDF.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Planner')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    Expanded(child: _statCard('Plans', _plans.length, Icons.auto_awesome, const Color(0xFF8B5CF6))),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard('Latest', _plans.isEmpty ? 0 : 1, Icons.schedule_outlined, const Color(0xFF0EA5E9))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptController,
                    minLines: 3, maxLines: 6, maxLength: 3000,
                    decoration: const InputDecoration(labelText: 'What should the AI Planner generate?', hintText: 'Example: Build a 7-day plan focused on savings, exercise, overdue tasks and spiritual growth.', prefixIcon: Icon(Icons.edit_note_outlined)),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome),
                    label: Text(_generating ? 'Generating...' : 'Generate New Plan'),
                  ),
                  const SizedBox(height: 16),
                  if (_plans.isEmpty) const Text('No plans generated yet.'),
                  ..._plans.map((plan) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat('yMMMd, h:mm a').format(plan.createdAt),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete plan',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(plan),
                                  ),
                                ],
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _viewPlan(plan),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    plan.content,
                                    maxLines: 6,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, height: 1.45),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _viewPlan(plan),
                                      icon: const Icon(Icons.visibility_outlined, size: 18),
                                      label: const Text('View Plan'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: () => _downloadPdf(plan),
                                      icon: const Icon(Icons.download_outlined, size: 18),
                                      label: const Text('PDF'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color accent) {
    final backgrounds = <String, Color>{
      'Total': const Color(0xFFEFF8FF),
      'Saved': const Color(0xFFECFDF5),
      'This month': const Color(0xFFF5F3FF),
      'Selected': const Color(0xFFFFFBEB),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: backgrounds[label] ?? const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(13),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: accent, size: 17)),
        const SizedBox(width: 8),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

}

class _AiPlanViewerScreen extends StatelessWidget {
  final AiPlan plan;
  final Future<void> Function() onDownloadPdf;

  const _AiPlanViewerScreen({
    required this.plan,
    required this.onDownloadPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View AI Plan'),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: onDownloadPdf,
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI Plan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('EEEE, d MMMM y • h:mm a')
                                    .format(plan.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if ((plan.provider ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.smart_toy_outlined, size: 16),
                            label: Text(plan.provider!),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (plan.usedSharedKey)
                            const Chip(
                              avatar: Icon(Icons.card_giftcard_outlined, size: 16),
                              label: Text('Shared AI plan'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  plan.content.trim().isEmpty
                      ? 'This AI plan has no content.'
                      : plan.content.trim(),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onDownloadPdf,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download PDF'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

