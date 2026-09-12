import 'package:flutter/material.dart';
import '../services/social_media_planner_service.dart';
import 'social_media_post_analytics_screen.dart';

class SocialMediaReportScreen extends StatefulWidget {
  const SocialMediaReportScreen({super.key});
  @override
  State<SocialMediaReportScreen> createState() =>
      _SocialMediaReportScreenState();
}

class _SocialMediaReportScreenState extends State<SocialMediaReportScreen> {
  final _service = const SocialMediaPlannerService();
  String _period = 'month';
  String _platform = '';
  String _status = '';
  Map<String, dynamic> _report = {};
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _int(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final r = await _service.report(
          period: _period, platform: _platform, status: _status);
      if (!mounted) return;
      setState(() {
        _report = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load report: $e')));
    }
  }

  Future<void> _syncAnalytics() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final result = await _service.syncAnalytics();
      await _load();
      if (!mounted) return;
      final synced = _int(result['synced']);
      final failed = _int(result['failed']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Analytics sync complete: $synced synced${failed > 0 ? ', $failed failed' : ''}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not sync analytics: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _report['summary'] is Map
        ? Map<String, dynamic>.from(_report['summary'])
        : <String, dynamic>{};
    final platforms = _report['platform_breakdown'] is Map
        ? Map<String, dynamic>.from(_report['platform_breakdown'])
        : <String, dynamic>{};
    final sync = _report['sync'] is Map
        ? Map<String, dynamic>.from(_report['sync'])
        : <String, dynamic>{};
    final analytics = _report['analytics'] is Map
        ? Map<String, dynamic>.from(_report['analytics'])
        : <String, dynamic>{};
    final raw = _report['posts'];
    final posts = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Media Reports'),
        actions: [
          IconButton(
            tooltip: 'Sync analytics now',
            onPressed: _syncing ? null : _syncAnalytics,
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
                child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                DropdownButtonFormField<String>(
                  initialValue: _period,
                  decoration: const InputDecoration(labelText: 'Period'),
                  items: const [
                    DropdownMenuItem(value: 'today', child: Text('Today')),
                    DropdownMenuItem(value: 'week', child: Text('This Week')),
                    DropdownMenuItem(value: 'month', child: Text('This Month')),
                    DropdownMenuItem(value: 'year', child: Text('This Year')),
                    DropdownMenuItem(value: 'all', child: Text('All Time')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _period = v);
                    _load();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _platform,
                  decoration: const InputDecoration(labelText: 'Platform'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All Platforms')),
                    DropdownMenuItem(
                        value: 'instagram', child: Text('Instagram')),
                    DropdownMenuItem(
                        value: 'facebook', child: Text('Facebook')),
                    DropdownMenuItem(value: 'x', child: Text('X (Twitter)')),
                    DropdownMenuItem(value: 'tiktok', child: Text('TikTok')),
                    DropdownMenuItem(
                        value: 'linkedin', child: Text('LinkedIn')),
                    DropdownMenuItem(
                        value: 'whatsapp_status',
                        child: Text('WhatsApp Status')),
                    DropdownMenuItem(
                        value: 'whatsapp_channel',
                        child: Text('WhatsApp Channel')),
                  ],
                  onChanged: (v) {
                    setState(() => _platform = v ?? '');
                    _load();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                        value: 'scheduled', child: Text('Scheduled')),
                    DropdownMenuItem(
                        value: 'ready_to_share', child: Text('Ready to Post')),
                    DropdownMenuItem(
                        value: 'published', child: Text('Published')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (v) {
                    setState(() => _status = v ?? '');
                    _load();
                  },
                ),
              ]),
            )),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_sync_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Automatic analytics',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            sync['last_synced_at'] == null
                                ? 'Waiting for the first provider sync'
                                : 'Last sync: ${sync['last_synced_at']}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (_int(sync['error_rows']) > 0)
                            Text(
                              '${_int(sync['error_rows'])} record(s) need account/API attention',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sync now',
                      onPressed: _syncing ? null : _syncAnalytics,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _Metric('Total', _int(summary['total_posts'])),
                _Metric('Published', _int(summary['published'])),
                _Metric('Scheduled', _int(summary['scheduled'])),
                _Metric('Ready', _int(summary['ready_to_post'])),
                _Metric('Overdue', _int(summary['overdue'])),
                _Metric('Drafts', _int(summary['draft'])),
                _Metric('Views', _int(analytics['total_views'])),
                _Metric('Reach', _int(analytics['total_reach'])),
                _Metric('Impressions', _int(analytics['total_impressions'])),
                _Metric('Likes', _int(analytics['total_likes'])),
                _Metric('Comments', _int(analytics['total_comments'])),
                _Metric('Shares', _int(analytics['total_shares'])),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Platforms',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...const {
              'instagram': 'Instagram',
              'facebook': 'Facebook',
              'x': 'X (Twitter)',
              'tiktok': 'TikTok',
              'linkedin': 'LinkedIn',
              'whatsapp_status': 'WhatsApp Status',
              'whatsapp_channel': 'WhatsApp Channel'
            }.entries.map((e) => Card(
                child: ListTile(
                    title: Text(e.value),
                    trailing: Text(_int(platforms[e.key]).toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800))))),
            const SizedBox(height: 18),
            Text('Post History (${posts.length})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...posts.map((post) => Card(
                    child: ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text((post['title'] ?? 'Untitled').toString()),
                  subtitle: Text(
                      '${(post['status'] ?? 'draft').toString().replaceAll('ready_to_share', 'Ready to Post').replaceAll('_', ' ')}\n${post['scheduled_at'] ?? ''}'),
                  trailing: const Icon(Icons.insights_outlined),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          SocialMediaPostAnalyticsScreen(post: post))),
                ))),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  const _Metric(this.label, this.value);
  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ]),
      ));
}
