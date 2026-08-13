import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/branding_service.dart';
import '../widgets/app_drawer.dart';
import '../services/reminder_alarm_service.dart';
import '../services/annual_planner_service.dart';
import '../models/annual_plan.dart';
import 'annual_plans_screen.dart';
import 'ai_planner_screen.dart';
import 'search_screen.dart';
import 'whats_included_screen.dart';

/// The Home tab — mirrors the web app's dashboard: stat cards, a
/// spending-by-category doughnut, an income-vs-expenses trend, and a
/// recent activity feed. The 20 modules themselves now live in the
/// drawer (see widgets/app_drawer.dart) rather than inline here, since
/// this screen's job is a quick glance, not a full module directory.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  AnnualPlanSummary? _annualPlans;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiClient.instance.get('dashboard', cacheable: true);
      AnnualPlanSummary? annualPlans;
      try {
        annualPlans = await AnnualPlannerService().getPlans(year: DateTime.now().year);
      } on ApiException {
        // Dashboard should remain usable even if Annual Plans is temporarily unavailable.
      }
      if (!mounted) return;
      setState(() {
        _stats = response as Map<String, dynamic>;
        _annualPlans = annualPlans;
        _loading = false;
      });
    } on ApiException {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(num amount) {
    return (BrandingService.cached ?? BrandingInfo(siteName: '')).formatMoney(amount);
  }

  String _firstName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return '';
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.first;
  }

  List<Map<String, dynamic>> _safeSpendingCategories() {
    final raw = _stats?['expenses_by_category'];
    if (raw is! List) return const [];

    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final rawTotal = map['total'];
      final total = rawTotal is num ? rawTotal.toDouble() : double.tryParse(rawTotal?.toString() ?? '');
      if (total == null || !total.isFinite || total <= 0) continue;
      map['total'] = total;
      result.add(map);
    }
    return result;
  }

  ({List<String> labels, List<num> income, List<num> expenses})? _safeTrend() {
    final rawLabels = _stats?['trend_labels'];
    final rawIncome = _stats?['income_trend'];
    final rawExpenses = _stats?['expense_trend'];
    if (rawLabels is! List || rawIncome is! List || rawExpenses is! List) return null;

    final length = [rawLabels.length, rawIncome.length, rawExpenses.length]
        .reduce((a, b) => a < b ? a : b);
    if (length <= 0) return null;

    final labels = <String>[];
    final income = <num>[];
    final expenses = <num>[];
    for (var i = 0; i < length; i++) {
      final label = rawLabels[i]?.toString().trim() ?? '';
      final inValue = rawIncome[i] is num ? rawIncome[i] as num : num.tryParse(rawIncome[i]?.toString() ?? '');
      final outValue = rawExpenses[i] is num ? rawExpenses[i] as num : num.tryParse(rawExpenses[i]?.toString() ?? '');
      if (label.isEmpty || inValue == null || outValue == null) continue;
      labels.add(label);
      income.add(inValue);
      expenses.add(outValue);
    }

    if (labels.isEmpty) return null;
    return (labels: labels, income: income, expenses: expenses);
  }

  List<Map<String, dynamic>> _todaysTopTasks() {
    final raw = (_stats?['top_tasks'] as List?) ?? const [];
    final today = DateTime.now();
    final todayKey = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['due_date']?.toString() == todayKey)
        .take(3)
        .toList();
  }

  Future<void> _toggleAlarmMute() async {
    try {
      final muted = await ReminderAlarmService().toggleMute();
      if (mounted) context.read<AuthService>().updateAlarmsMuted(muted);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(muted ? 'Reminder alarms muted.' : 'Reminder alarms unmuted.'),
        ));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${_firstName(auth.user?.name)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          IconButton(
            icon: Icon(auth.user?.alarmsMuted == true ? Icons.notifications_off : Icons.notifications_active),
            tooltip: auth.user?.alarmsMuted == true ? 'Reminder alarms muted — tap to unmute' : 'Reminder alarms on — tap to mute',
            onPressed: _toggleAlarmMute,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _StatCard(label: 'Income (mo)', value: _money(_stats?['monthly_income'] ?? 0), color: const Color(0xFF059669)),
                      _StatCard(label: 'Expenses (mo)', value: _money(_stats?['monthly_expenses'] ?? 0), color: const Color(0xFFE11D48)),
                      _StatCard(label: 'Active Projects', value: '${_stats?['active_projects'] ?? 0}', color: const Color(0xFF3B82F6)),
                      _StatCard(label: 'Reminders (7d)', value: '${_stats?['upcoming_reminders'] ?? 0}', color: const Color(0xFFD97706)),
                    ],
                  ),
                  if (_todaysTopTasks().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text("Today's Top 3", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._todaysTopTasks().asMap().entries.map((entry) {
                      final index = entry.key;
                      final task = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        elevation: 0,
                        color: const Color(0xFFF0FDF4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFBBF7D0))),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFF059669),
                            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(task['title'] ?? '', style: const TextStyle(fontSize: 13)),
                          trailing: Text(task['source'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                  Card(
                    color: const Color(0xFFF5F3FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFDDD6FE))),
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome, color: Color(0xFF6D28D9)),
                      title: const Text('AI Planner', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4C1D95))),
                      subtitle: const Text('Generate a personalized plan from your data', style: TextStyle(color: Color(0xFF5B21B6), fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF6D28D9)),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiPlannerScreen())),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFFECFDF5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFA7F3D0))),
                    child: ListTile(
                      leading: const Icon(Icons.explore_outlined, color: Color(0xFF059669)),
                      title: const Text("Explore What's Included", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                      subtitle: const Text('See everything you can track in one place', style: TextStyle(color: Color(0xFF047857), fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF059669)),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WhatsIncludedScreen())),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final categories = _safeSpendingCategories();
                      if (categories.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Spending by Category', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          _SpendingDoughnut(categories: categories),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final trend = _safeTrend();
                      if (trend == null) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Income vs Expenses (last 6 months)', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          _IncomeExpenseTrend(
                            labels: trend.labels,
                            income: trend.income,
                            expenses: trend.expenses,
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                  if (_annualPlans != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Annual Plans ${DateTime.now().year}', style: Theme.of(context).textTheme.titleMedium),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnnualPlansScreen())),
                          child: const Text('View Plans'),
                        ),
                      ],
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_annualPlans!.completed} of ${_annualPlans!.total} completed'),
                                Text('${_annualPlans!.overallProgress}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(value: _annualPlans!.overallProgress / 100),
                            if (_annualPlans!.plans.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ..._annualPlans!.plans.take(3).map((plan) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(plan.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(plan.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    Text('${plan.progressPercent}%'),
                                  ],
                                ),
                              )),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SpendingDoughnut extends StatelessWidget {
  final List<Map<String, dynamic>> categories;

  const _SpendingDoughnut({required this.categories});

  @override
  Widget build(BuildContext context) {
    final safeCategories = <Map<String, dynamic>>[];
    double total = 0;

    for (final category in categories) {
      final raw = category['total'];
      final value = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
      if (value == null || !value.isFinite || value <= 0) continue;
      safeCategories.add({...category, 'total': value});
      total += value;
    }

    if (safeCategories.isEmpty || total <= 0 || !total.isFinite) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final category in safeCategories.take(8)) ...[
              Builder(
                builder: (context) {
                  final value = (category['total'] as num).toDouble();
                  final ratio = (value / total).clamp(0.0, 1.0);
                  final label = (category['category']?.toString().trim().isNotEmpty ?? false)
                      ? category['category'].toString().trim()
                      : 'Other';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 12),
                            Text('${(ratio * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IncomeExpenseTrend extends StatelessWidget {
  final List<String> labels;
  final List<num> income;
  final List<num> expenses;

  const _IncomeExpenseTrend({required this.labels, required this.income, required this.expenses});

  @override
  Widget build(BuildContext context) {
    var itemCount = labels.length;
    if (income.length < itemCount) itemCount = income.length;
    if (expenses.length < itemCount) itemCount = expenses.length;
    if (itemCount <= 0) return const SizedBox.shrink();

    final rows = <({String label, double income, double expense})>[];
    double maxValue = 1;

    for (var i = 0; i < itemCount; i++) {
      final label = labels[i].trim();
      final incomeValue = income[i].toDouble();
      final expenseValue = expenses[i].toDouble();
      if (label.isEmpty || !incomeValue.isFinite || !expenseValue.isFinite) continue;
      rows.add((label: label, income: incomeValue, expense: expenseValue));
      if (incomeValue > maxValue) maxValue = incomeValue;
      if (expenseValue > maxValue) maxValue = expenseValue;
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final row in rows) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 7),
                    _TrendBar(
                      label: 'Income',
                      value: row.income,
                      maxValue: maxValue,
                      color: const Color(0xFF059669),
                    ),
                    const SizedBox(height: 5),
                    _TrendBar(
                      label: 'Expenses',
                      value: row.expense,
                      maxValue: maxValue,
                      color: const Color(0xFFE11D48),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;

  const _TrendBar({required this.label, required this.value, required this.maxValue, required this.color});

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}
