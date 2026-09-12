import 'package:flutter/material.dart';

import '../config/module_configs.dart';
import '../services/health_wellbeing_service.dart';
import 'dynamic_crud_screen.dart';

class HealthWellbeingScreen extends StatefulWidget {
  const HealthWellbeingScreen({super.key});

  @override
  State<HealthWellbeingScreen> createState() => _HealthWellbeingScreenState();
}

class _HealthWellbeingScreenState extends State<HealthWellbeingScreen> {
  final _service = const HealthWellbeingService();
  bool _loading = true;
  String? _error;
  int _days = 7;
  Map<String, dynamic> _summary = <String, dynamic>{};

  Map<String, dynamic> get _daily => _summary['daily'] is Map
      ? Map<String, dynamic>.from(_summary['daily'] as Map)
      : <String, dynamic>{};

  Map<String, dynamic> get _trend => _summary['trend'] is Map
      ? Map<String, dynamic>.from(_summary['trend'] as Map)
      : <String, dynamic>{};

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
      final result = await _service.summary(days: _days);
      if (!mounted) return;
      setState(() {
        _summary = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your wellbeing summary.';
      });
    }
  }

  void _openModule(String endpoint) {
    final config = moduleConfigByEndpoint(endpoint);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => DynamicCrudScreen(config: config)))
        .then((_) => _load());
  }

  String _value(dynamic value, {String suffix = ''}) {
    if (value == null || value.toString().trim().isEmpty) return '—';
    return '${value.toString()}$suffix';
  }

  Widget _metric(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _moduleTile(String title, String subtitle, String endpoint, IconData icon) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _openModule(endpoint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health & Wellbeing'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _days,
            onSelected: (value) {
              setState(() => _days = value);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('7-day trend')),
              PopupMenuItem(value: 14, child: Text('14-day trend')),
              PopupMenuItem(value: 30, child: Text('30-day trend')),
            ],
          ),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _summary.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 220), Center(child: CircularProgressIndicator())],
              )
            : _error != null && _summary.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      const Icon(Icons.error_outline_rounded, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    children: [
                      const Text('Your daily picture', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      const Text('Diet, exercise, sleep, health records and your daily wellbeing check-in are connected here.', style: TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 5 : 2,
                        childAspectRatio: 1.35,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          _metric('Sleep', _daily['sleep_hours'] == null ? '—' : '${_daily['sleep_hours']} hrs', Icons.bedtime_outlined),
                          _metric('Exercise', '${_daily['exercise_minutes'] ?? 0} min', Icons.directions_run_rounded),
                          _metric('Meals', '${_daily['meals_logged'] ?? 0}', Icons.restaurant_outlined),
                          _metric('Water', '${_daily['water_percent'] ?? 0}%', Icons.water_drop_outlined),
                          _metric('Wellbeing', _daily['wellbeing_score'] == null ? '—' : '${_daily['wellbeing_score']}/10', Icons.favorite_border_rounded),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _moduleTile('Diet', 'Meals and food records', 'diet-logs', Icons.restaurant_outlined),
                      _moduleTile('Exercise', 'Sessions, duration and intensity', 'exercise-logs', Icons.directions_run_rounded),
                      _moduleTile('Sleep', 'Duration and sleep quality', 'sleep-logs', Icons.bedtime_outlined),
                      _moduleTile('Health', 'Checkups and optional measurements', 'health-checkups', Icons.monitor_heart_outlined),
                      _moduleTile('Daily Wellbeing', 'Mood, energy, stress, water, symptoms and self-care', 'wellbeing', Icons.favorite_border_rounded),
                      const SizedBox(height: 18),
                      Text('Recent trend · $_days days', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Wrap(
                            spacing: 22,
                            runSpacing: 14,
                            children: [
                              _trendItem('Avg sleep', _value(_trend['avg_sleep_hours'], suffix: ' hrs')),
                              _trendItem('Exercise days', _value(_trend['exercise_days'])),
                              _trendItem('Avg exercise', _value(_trend['avg_exercise_minutes'], suffix: ' min')),
                              _trendItem('Avg water', _value(_trend['avg_water_percent'], suffix: '%')),
                              _trendItem('Avg wellbeing', _trend['avg_wellbeing_score'] == null ? '—' : '${_trend['avg_wellbeing_score']}/10'),
                              _trendItem('Meals logged', _value(_trend['meals_logged'])),
                            ],
                          ),
                        ),
                      ),
                      if (_summary['observations'] is List && (_summary['observations'] as List).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('From your records', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: (_summary['observations'] as List)
                                  .map((item) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.check_circle_outline_rounded, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(item.toString())),
                                          ],
                                        ),
                                      ))
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        (_summary['notice'] ?? 'This is a personal wellbeing summary, not a medical diagnosis.').toString(),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _trendItem(String label, String value) {
    return SizedBox(
      width: 125,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
