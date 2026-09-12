import 'package:flutter/material.dart';
import '../services/social_media_planner_service.dart';

class SocialMediaPostAnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const SocialMediaPostAnalyticsScreen({super.key, required this.post});

  @override
  State<SocialMediaPostAnalyticsScreen> createState() =>
      _SocialMediaPostAnalyticsScreenState();
}

class _SocialMediaPostAnalyticsScreenState
    extends State<SocialMediaPostAnalyticsScreen> {
  final _service = const SocialMediaPlannerService();
  Map<String, dynamic> _data = {};
  bool _loading = true;
  bool _syncing = false;

  int get _postId {
    final v = widget.post['id'];
    return v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
  }

  int _int(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final d = await _service.analytics(_postId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load post performance: $e')));
    }
  }

  Future<void> _syncNow() async {
    if (_syncing || _postId <= 0) return;
    setState(() => _syncing = true);
    try {
      final result = await _service.syncPostAnalytics(_postId);
      await _load();
      if (!mounted) return;
      final entries = result.values.whereType<Map>().toList();
      final synced = entries.where((e) => e['ok'] == true).length;
      final failed =
          entries.where((e) => e['ok'] != true && e['skipped'] != true).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Post analytics: $synced synced${failed > 0 ? ', $failed failed' : ''}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not sync post analytics: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _edit(String platform, Map<String, dynamic>? metric) async {
    final names = [
      'views',
      'reach',
      'impressions',
      'likes',
      'comments',
      'shares',
      'saves',
      'clicks',
      'replies'
    ];
    final c = {
      for (final n in names)
        n: TextEditingController(text: _int(metric?[n]).toString())
    };
    final external = TextEditingController(
        text: (metric?['external_post_id'] ?? '').toString());
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                18, 4, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Update ${platform.replaceAll('_', ' ')} performance',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  ...c.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                          controller: e.value,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText:
                                  e.key.replaceAll('_', ' ').toUpperCase())))),
                  TextField(
                      controller: external,
                      decoration: const InputDecoration(
                          labelText: 'External Post ID (optional)')),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save Performance')),
                ]),
          )),
    );
    if (ok == true) {
      await _service.updateAnalytics(
          postId: _postId,
          platform: platform,
          views: _int(c['views']!.text),
          reach: _int(c['reach']!.text),
          impressions: _int(c['impressions']!.text),
          likes: _int(c['likes']!.text),
          comments: _int(c['comments']!.text),
          shares: _int(c['shares']!.text),
          saves: _int(c['saves']!.text),
          clicks: _int(c['clicks']!.text),
          replies: _int(c['replies']!.text),
          externalPostId: external.text.trim());
      await _load();
    }
    for (final x in c.values) {
      x.dispose();
    }
    external.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = _data['post'] is Map
        ? Map<String, dynamic>.from(_data['post'] as Map)
        : widget.post;
    final raw = _data['metrics'];
    final metrics = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final by = {for (final m in metrics) (m['platform'] ?? '').toString(): m};
    final rp = post['platforms'];
    final platforms =
        rp is List ? rp.map((e) => e.toString()).toList() : <String>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Performance'),
        actions: [
          IconButton(
            tooltip: 'Sync analytics now',
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                if (_loading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 12)
                ],
                Card(
                    child: ListTile(
                        title: Text(
                            (post['title'] ?? 'Social media post').toString()),
                        subtitle: const Text(
                            'Views, reach, likes, comments, shares, saves, clicks and engagement.'))),
                const SizedBox(height: 12),
                ...platforms.map((platform) {
                  final m = by[platform];
                  return Card(
                      child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          platform
                                              .replaceAll('_', ' ')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800))),
                                  TextButton(
                                      onPressed: () => _edit(platform, m),
                                      child: Text(m == null
                                          ? 'Add Metrics'
                                          : 'Edit Manual'))
                                ]),
                                if (m?['synced_at'] != null)
                                  Text(
                                      'Last API/manual sync: ${m?['synced_at']}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B))),
                                if (m?['raw_metrics'] is Map &&
                                    (m?['raw_metrics'] as Map)['sync_status'] ==
                                        'error')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                        "API sync needs attention: ${(m?['raw_metrics'] as Map)['sync_error'] ?? 'Unknown provider error'}",
                                        style: const TextStyle(fontSize: 11)),
                                  ),
                                const SizedBox(height: 8),
                                GridView.count(
                                    crossAxisCount: 3,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 1.25,
                                    children: [
                                      _Metric('Views', _int(m?['views'])),
                                      _Metric('Reach', _int(m?['reach'])),
                                      _Metric('Likes', _int(m?['likes'])),
                                      _Metric('Comments', _int(m?['comments'])),
                                      _Metric('Shares', _int(m?['shares'])),
                                      _Metric('Saves', _int(m?['saves'])),
                                    ]),
                                const SizedBox(height: 8),
                                Text(
                                    'Engagement: ${(m?['engagement_rate'] ?? 0)}%',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ])));
                }),
              ])),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  const _Metric(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$value',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)))
      ]));
}
