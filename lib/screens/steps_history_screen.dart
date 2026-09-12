import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/step_tracking_service.dart';

class StepsHistoryScreen extends StatefulWidget {
  const StepsHistoryScreen({super.key});

  @override
  State<StepsHistoryScreen> createState() => _StepsHistoryScreenState();
}

class _StepsHistoryScreenState extends State<StepsHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await StepTrackingService.instance.history(days: 30);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  int _int(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Steps History')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _items.isEmpty
            ? ListView(children: const [
                SizedBox(height: 220),
                Center(child: CircularProgressIndicator()),
              ])
            : _items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(28),
                    children: const [
                      SizedBox(height: 100),
                      Icon(Icons.directions_walk_rounded, size: 54),
                      SizedBox(height: 12),
                      Text(
                        'No step history is available yet.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      final steps = _int(item['steps']);
                      final goal = _int(item['daily_goal']) <= 0
                          ? 500
                          : _int(item['daily_goal']);
                      final date = DateTime.tryParse(
                        '${item['tracking_date'] ?? item['date'] ?? ''}',
                      );
                      final progress =
                          goal > 0 ? (steps / goal).clamp(0, 1).toDouble() : 0.0;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      date == null
                                          ? 'Recorded day'
                                          : DateFormat('EEE, d MMM yyyy')
                                              .format(date),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$steps / $goal',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(value: progress),
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
