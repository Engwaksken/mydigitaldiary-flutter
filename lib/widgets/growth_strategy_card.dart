import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/growth_strategy_service.dart';

class GrowthStrategyCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onChanged;

  const GrowthStrategyCard({super.key, required this.data, required this.onChanged});

  @override
  State<GrowthStrategyCard> createState() => _GrowthStrategyCardState();
}

class _GrowthStrategyCardState extends State<GrowthStrategyCard> {
  bool _joining = false;
  bool _sharing = false;

  Map<String, dynamic> _map(String key) {
    final raw = widget.data[key];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await const GrowthStrategyService().joinChallenge();
      widget.onChanged();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not join the challenge right now.')));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final referral = await const GrowthStrategyService().createReferral();
      final text = [
        referral['share_text'] ?? 'I’m using My Digital Diary to plan my day, manage my money and track my goals.',
        referral['url'] ?? '',
      ].where((e) => e.toString().trim().isNotEmpty).join('\n');
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'Join me on My Digital Diary',
        ),
      );
      await const GrowthStrategyService().track('referral_shared', source: 'dashboard');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create your invite right now.')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activation = _map('activation');
    final challenge = _map('challenge');
    final trust = _map('trust');
    final steps = activation['steps'] is List ? List<dynamic>.from(activation['steps'] as List) : const <dynamic>[];
    final joined = challenge['joined'] == true;
    final progress = (challenge['progress_percent'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TAKE BACK YOUR ATTENTION', style: TextStyle(fontSize: 9.5, letterSpacing: .7, fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
            SizedBox(height: 3),
            Text('Build your own progress, not just your feed.', style: TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w800)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(99)), child: const Text('Private', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF047857)))),
        ]),
        const SizedBox(height: 13),
        if (steps.isNotEmpty) ...[
          Text('First value · ${activation['completed'] ?? 0}/${activation['total'] ?? 3}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          LinearProgressIndicator(value: ((activation['percent'] as num?)?.toDouble() ?? 0) / 100, minHeight: 6, borderRadius: BorderRadius.circular(99)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: steps.map((raw) {
            final step = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
            final complete = step['complete'] == true;
            return Chip(visualDensity: VisualDensity.compact, avatar: Icon(complete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 16), label: Text((step['label'] ?? '').toString(), style: const TextStyle(fontSize: 10.5)));
          }).toList()),
          const SizedBox(height: 14),
        ],
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('30 DAYS WITH MY DIGITAL DIARY', style: TextStyle(fontSize: 9.5, letterSpacing: .5, fontWeight: FontWeight.w900, color: Color(0xFF6D28D9))),
          const SizedBox(height: 3),
          Text((challenge['title'] ?? '30 Days With My Digital Diary').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Plan, act, record and reflect consistently.', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
          if (joined) ...[
            const SizedBox(height: 9),
            LinearProgressIndicator(value: progress.clamp(0, 100) / 100, minHeight: 6, borderRadius: BorderRadius.circular(99)),
            const SizedBox(height: 5),
            Text('${challenge['meaningful_days'] ?? 0} meaningful day(s)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
          ] else ...[
            const SizedBox(height: 9),
            FilledButton(onPressed: _joining ? null : _join, child: Text(_joining ? 'Joining…' : 'Join 30-Day Challenge')),
          ],
        ])),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _sharing ? null : _share, icon: const Icon(Icons.share_outlined, size: 18), label: Text(_sharing ? 'Preparing invite…' : 'Invite a friend')),
        const SizedBox(height: 8),
        Text((trust['message'] ?? 'Private diary content is never included in shared progress cards.').toString(), style: const TextStyle(fontSize: 9.8, height: 1.35, color: Color(0xFF64748B))),
      ]),
    );
  }
}
