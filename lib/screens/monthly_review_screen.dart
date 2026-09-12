import 'package:flutter/material.dart';
import '../services/api_client.dart';

class MonthlyReviewScreen extends StatefulWidget {
  const MonthlyReviewScreen({super.key});

  @override
  State<MonthlyReviewScreen> createState() => _MonthlyReviewScreenState();
}

class _MonthlyReviewScreenState extends State<MonthlyReviewScreen> {
  Map<String, dynamic>? _review;
  bool _loading = true;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final key = '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
      final response = await ApiClient.instance.get('monthly-review?month=$key');
      if (!mounted) return;
      final data = response is Map && response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};
      setState(() {
        _review = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  num _num(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;

  String _money(dynamic value) {
    final number = _num(value).toDouble();
    final text = number
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return 'UGX $text';
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_month.year, _month.month, 1),
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: now,
      helpText: 'Choose a month',
    );
    if (picked == null) return;
    setState(() => _month = DateTime(picked.year, picked.month));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Month in Review'),
        actions: [
          IconButton(
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Choose month',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _review == null || _review!.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      Text(
                        _review!['month']?.toString() ?? 'This month',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _review!['period']?.toString() ?? '',
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      _moneyGrid(),
                      const SizedBox(height: 12),
                      _momentumCard(),
                      const SizedBox(height: 12),
                      _comparisonCard(),
                      const SizedBox(height: 12),
                      _productivityCard(),
                      const SizedBox(height: 12),
                      _valueCard(),
                      const SizedBox(height: 12),
                      _simpleListCard(
                        'Your next 3 actions',
                        Icons.arrow_forward_rounded,
                        const Color(0xFF00897B),
                        _review!['next_actions'] ?? _review!['focus_next_month'],
                      ),
                      const SizedBox(height: 12),
                      _simpleListCard(
                        'Wins worth keeping',
                        Icons.emoji_events_outlined,
                        const Color(0xFFF59E0B),
                        _review!['wins'],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _moneyGrid() {
    final money = _map(_review!['money']);
    final items = [
      ('Income', money['income'], Icons.trending_up, const Color(0xFF047857), const Color(0xFFECFDF5)),
      ('Expenses', money['expenses'], Icons.receipt_long_outlined, const Color(0xFFBE123C), const Color(0xFFFFF1F2)),
      ('Saved', money['saved'], Icons.savings_outlined, const Color(0xFF6D28D9), const Color(0xFFF5F3FF)),
      ('Net', money['net'], Icons.balance_outlined, const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: 1.72,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.$5,
                borderRadius: BorderRadius.circular(15),
                border: Border(left: BorderSide(color: item.$4, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(item.$3, size: 17, color: item.$4),
                      const SizedBox(width: 6),
                      Text(
                        item.$1,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: item.$4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _money(item.$2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _momentumCard() {
    final momentum = _map(_review!['momentum']);
    final score = _num(momentum['score']).toDouble().clamp(0, 100);
    final change = _num(momentum['change']).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MONTHLY MOMENTUM',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5), letterSpacing: .4),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(score.toStringAsFixed(0), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 3),
                child: Text('/100', style: TextStyle(color: Colors.black45, fontSize: 12)),
              ),
              const Spacer(),
              if (change != 0)
                Row(
                  children: [
                    Icon(change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 15, color: change > 0 ? const Color(0xFF059669) : const Color(0xFFE11D48)),
                    Text(
                      '${change.abs()} pts',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: change > 0 ? const Color(0xFF059669) : const Color(0xFFE11D48),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Text(momentum['label']?.toString() ?? 'Building momentum', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4338CA))),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: score / 100,
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 10),
          Text(momentum['message']?.toString() ?? '', style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xAB000000))),
        ],
      ),
    );
  }

  Widget _comparisonCard() {
    final comparison = _map(_review!['comparison']);
    final previous = comparison['previous_month']?.toString() ?? 'last month';
    final items = [
      ('Income', comparison['income_change_percent'], false, '%', Icons.account_balance_wallet_outlined),
      ('Spending', comparison['expense_change_percent'], true, '%', Icons.receipt_long_outlined),
      ('Savings', comparison['saving_change_percent'], false, '%', Icons.savings_outlined),
      ('Tasks', comparison['task_completion_change_points'], false, ' pts', Icons.checklist_rounded),
    ];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compared with $previous', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            const Text('A quick view of what moved.', style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.05,
              children: items.map((item) {
                final raw = item.$2;
                if (raw == null) return _deltaTile(item.$1, 'No previous data', Colors.black45, item.$5);
                final value = _num(raw).toDouble();
                final good = item.$3 ? value < 0 : value > 0;
                final same = value.abs() < .05;
                final color = same ? Colors.black54 : (good ? const Color(0xFF059669) : const Color(0xFFE11D48));
                final label = same ? 'No change' : '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}${item.$4}';
                return _deltaTile(item.$1, label, color, item.$5);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deltaTile(String title, String value, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 17, color: Colors.black45),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _productivityCard() {
    final p = _map(_review!['productivity']);
    final w = _map(_review!['wellbeing']);
    final percent = _num(p['completion_percent']).toDouble();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Productivity & wellbeing', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00897B), fontSize: 19)),
          ]),
          const SizedBox(height: 9),
          LinearProgressIndicator(value: (percent / 100).clamp(0, 1), minHeight: 6, borderRadius: BorderRadius.circular(20)),
          const SizedBox(height: 13),
          Wrap(spacing: 15, runSpacing: 10, children: [
            _metric('Tasks', '${p['completed_tasks'] ?? 0}/${p['total_tasks'] ?? 0}'),
            _metric('Meetings', '${p['meetings'] ?? 0}'),
            _metric('Plans', '${p['plans_completed'] ?? 0}'),
            _metric('Exercise', '${w['exercise_sessions'] ?? 0}'),
          ]),
        ]),
      ),
    );
  }

  Widget _valueCard() {
    final value = _map(_review!['value']);
    final items = [
      ('Tasks', value['tasks_completed'] ?? 0, Icons.check_circle_outline),
      ('Finance', value['financial_records'] ?? 0, Icons.account_balance_wallet_outlined),
      ('AI plans', value['ai_plans'] ?? 0, Icons.auto_awesome_outlined),
      ('Meetings', value['meetings'] ?? 0, Icons.groups_outlined),
      ('Notes', value['notes_created'] ?? 0, Icons.note_alt_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('What My Digital Diary helped you manage', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        const Text('Your activity becomes more valuable when it stays connected.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items
                .map((item) => Container(
                      width: 88,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(item.$3, size: 18, color: const Color(0xFF0284C7)),
                        const SizedBox(height: 6),
                        Text('${item.$2}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        Text(item.$1, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ]),
                    ))
                .toList(),
          ),
        ),
      ]),
    );
  }

  Widget _metric(String label, String value) => SizedBox(
        width: 82,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _simpleListCard(String title, IconData icon, Color color, dynamic raw) {
    final items = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 10),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.circle, size: 6, color: color),
                  const SizedBox(width: 9),
                  Expanded(child: Text(e, style: const TextStyle(fontSize: 13, height: 1.35))),
                ]),
              )),
        ]),
      ),
    );
  }
}
