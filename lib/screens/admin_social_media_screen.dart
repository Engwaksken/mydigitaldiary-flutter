import 'package:flutter/material.dart';

import '../services/social_media_planner_service.dart';

class AdminSocialMediaScreen extends StatefulWidget {
  const AdminSocialMediaScreen({super.key});

  @override
  State<AdminSocialMediaScreen> createState() => _AdminSocialMediaScreenState();
}

class _AdminSocialMediaScreenState extends State<AdminSocialMediaScreen> {
  final _service = const SocialMediaPlannerService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.adminOverview();
      final rawUsers = data['users'];
      if (!mounted) return;
      setState(() {
        _summary = data['summary'] is Map
            ? Map<String, dynamic>.from(data['summary'] as Map)
            : <String, dynamic>{};
        _users = rawUsers is List
            ? rawUsers
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Social Media')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Admin Social Media API is not available',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      const Text(
                        'The Mobile admin screen is ready, but Laravel must expose the admin/social-media API endpoints before user-wide account management can load.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.black45)),
                    ],
                  ),
                ),
              ),
            ],
            if (_summary.isNotEmpty) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric(label: 'Users', value: '${_summary['users'] ?? 0}'),
                  _Metric(
                      label: 'Accounts', value: '${_summary['accounts'] ?? 0}'),
                  _Metric(
                      label: 'WhatsApp',
                      value: '${_summary['whatsapp_configured'] ?? 0}'),
                  _Metric(
                      label: 'Scheduled Posts',
                      value: '${_summary['scheduled_posts'] ?? 0}'),
                ],
              ),
              const SizedBox(height: 18),
            ],
            const Text('User Social Media Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (!_loading && _users.isEmpty && _error == null)
              const Card(
                  child: ListTile(
                      title: Text('No user social media settings found.')))
            else
              ..._users.map((user) => Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.person_outline_rounded),
                      title: Text((user['name'] ?? 'User').toString()),
                      subtitle: Text((user['email'] ?? '').toString()),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.chat_outlined),
                          title: const Text('WhatsApp'),
                          subtitle: Text(
                              (user['whatsapp_number'] ?? 'Not configured')
                                  .toString()),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.campaign_outlined),
                          title: const Text('Saved accounts'),
                          subtitle:
                              Text('${user['accounts_count'] ?? 0} account(s)'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule_outlined),
                          title: const Text('Scheduled posts'),
                          subtitle:
                              Text('${user['scheduled_posts_count'] ?? 0}'),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
}
