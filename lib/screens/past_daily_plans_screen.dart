import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';

class PastDailyPlansScreen extends StatefulWidget {
  const PastDailyPlansScreen({super.key});

  @override
  State<PastDailyPlansScreen> createState() => _PastDailyPlansScreenState();
}

class _PastDailyPlansScreenState extends State<PastDailyPlansScreen> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      dynamic response = await ApiClient.instance.get('daily-planner/history?period=all&per_page=50', cacheable: false);
      if (response is Map && response['data'] is List) response = response['data'];
      final rows = response is List
          ? response.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false)
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() { _plans = rows; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.message; });
    }
  }

  int _i(dynamic v) => int.tryParse((v ?? '0').toString()) ?? 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Past Tasks')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Historical progress is calculated for the exact day, including recurring task occurrences.', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          if (_loading && _plans.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 140), child: Center(child: CircularProgressIndicator()))
          else if (_error != null && _plans.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 100), child: Text(_error!, textAlign: TextAlign.center))
          else if (_plans.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(28), child: Text('No past daily plans found.', textAlign: TextAlign.center)))
          else
            ..._plans.map((plan) {
              final progress = _i(plan['progress']).clamp(0, 100);
              final date = DateTime.tryParse(plan['plan_date']?.toString() ?? '');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text(date == null ? (plan['plan_date'] ?? '').toString() : DateFormat('EEE, dd MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.w900))),
                      Text('$progress%', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 4),
                    Text((plan['title'] ?? 'My Daily Plan').toString(), style: const TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: progress / 100, minHeight: 7)),
                    const SizedBox(height: 6),
                    Text('${_i(plan['completed'])} completed · ${_i(plan['pending'])} pending · ${_i(plan['total'])} total', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ]),
                ),
              );
            }),
        ],
      ),
    ),
  );
}
