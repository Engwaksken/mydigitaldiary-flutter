import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/module_configs.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/reminder_alarm_service.dart';
import '../services/engagement_service.dart';
import '../services/daily_planner_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/engagement_dashboard_section.dart';
import 'annual_plans_screen.dart';
import 'daily_planner_screen.dart';
import 'dynamic_crud_screen.dart';
import 'expenses_screen.dart';
import 'financial_planner_screen.dart';
import 'finance_report_screen.dart';
import 'signatures_screen.dart';
import 'business_card_screen.dart';
import 'ai_planner_screen.dart';
import 'meetings_screen.dart';
import 'reminders_screen.dart';
import 'recent_activity_screen.dart';
import 'search_screen.dart';
import 'monthly_review_screen.dart';
import 'personalisation_screen.dart';
import 'goal_intelligence_screen.dart';
import 'social_media_planner_screen.dart';
import 'budgets_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  // Today's Focus has its own state. Do not store the dedicated endpoint
  // response back into _stats: the general dashboard/finance/insight refreshes
  // can replace _stats and previously made valid focus cards disappear.
  List<Map<String, dynamic>> _todayFocusItems = <Map<String, dynamic>>[];
  bool _loadingTodayFocus = false;
  String? _todayFocusError;

  Map<String, dynamic> _engagement = <String, dynamic>{};
  bool _loadingEngagement = false;

  Map<String, dynamic> _growth = <String, dynamic>{};

  Timer? _insightTimer;

  final ScrollController _dashboardScrollController = ScrollController();

  String _currencyCode = 'UGX';
  String _currencySymbol = 'UGX';
  double _currencyRate = 1.0;
  int _currencyDecimals = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _insightTimer?.cancel();
    _dashboardScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh the authoritative dashboard payload on resume. Today's Focus
      // is sourced only from /api/dashboard -> top_tasks.
      unawaited(_load());
    }
  }

  Future<void> _refreshHome() async {
    await _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadingTodayFocus = _todayFocusItems.isEmpty;
        _todayFocusError = null;
      });
    }

    Map<String, dynamic> data = <String, dynamic>{};
    String? dashboardError;

    try {
      dynamic response;

      try {
        response = await ApiClient.instance
            .get(
              'dashboard',
              cacheable: false,
            )
            .timeout(const Duration(seconds: 7));
      } catch (_) {
        response = await ApiClient.instance
            .get(
              'dashboard',
              cacheable: true,
            )
            .timeout(const Duration(seconds: 3));
      }

      if (response is Map) {
        final root = Map<String, dynamic>.from(response);
        final wrapped = root['data'];

        if (wrapped is Map &&
            (wrapped.containsKey('top_tasks') ||
                wrapped.containsKey('personal_progress') ||
                wrapped.containsKey('finance_summary') ||
                wrapped.containsKey('today_insight'))) {
          data = Map<String, dynamic>.from(wrapped);
        } else {
          data = root;
        }
      }
    } catch (_) {
      dashboardError = 'Could not refresh the dashboard right now.';
    }

    if (!mounted) return;

    final rawMainFocus = data['top_tasks'] is List
        ? data['top_tasks']
        : (data['today_focus'] is List ? data['today_focus'] : null);

    final mainFocus = rawMainFocus is List
        ? _normaliseTodayFocus(rawMainFocus)
        : <Map<String, dynamic>>[];

    setState(() {
      _stats = data;
      _applyCurrencyMetadata(data);
      _currencyCode = _extractCurrency(data) ?? _currencyCode;

      if (mainFocus.isNotEmpty) {
        _todayFocusItems = mainFocus;
        _todayFocusError = null;
      } else if (_todayFocusItems.isEmpty && dashboardError != null) {
        _todayFocusError = dashboardError;
      }

      _loadingTodayFocus = false;
      _loading = false;
    });

    unawaited(_refreshTodayFocusFromPlanner());
    unawaited(_refreshEngagement());
    unawaited(_refreshGrowth());
    unawaited(_refreshFinanceSummary());
    unawaited(_refreshTodayInsight());
  }

  Future<void> _refreshTodayFocusFromPlanner() async {
    if (!mounted) return;

    if (_todayFocusItems.isEmpty) {
      setState(() {
        _loadingTodayFocus = true;
        _todayFocusError = null;
      });
    }

    try {
      final plannerItems = await _todayPlannerFocus();

      if (!mounted) return;

      setState(() {
        if (plannerItems.isNotEmpty) {
          _todayFocusItems = plannerItems;
        }

        _todayFocusError = null;
        _loadingTodayFocus = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingTodayFocus = false;

        if (_todayFocusItems.isEmpty) {
          _todayFocusError =
              'Could not refresh Today’s Focus. Pull down to try again.';
        }
      });
    }
  }


  Future<List<Map<String, dynamic>>> _todayPlannerFocus() async {
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final plan = await DailyPlannerService()
        .getPlan(today)
        .timeout(const Duration(seconds: 6));

    final pending = plan.items
        .where(
          (item) =>
              !item.isCompleted &&
              item.title.trim().isNotEmpty,
        )
        .toList()
      ..sort((a, b) {
        int priorityWeight(String value) {
          switch (value.toLowerCase()) {
            case 'urgent':
            case 'high':
              return 0;
            case 'medium':
              return 1;
            default:
              return 2;
          }
        }

        final priorityCompare = priorityWeight(
          a.priority,
        ).compareTo(
          priorityWeight(b.priority),
        );

        if (priorityCompare != 0) {
          return priorityCompare;
        }

        final aTime = a.startTime?.trim() ?? '';
        final bTime = b.startTime?.trim() ?? '';

        if (aTime.isEmpty && bTime.isEmpty) {
          return a.title.toLowerCase().compareTo(
                b.title.toLowerCase(),
              );
        }

        if (aTime.isEmpty) return 1;
        if (bTime.isEmpty) return -1;

        return aTime.compareTo(bTime);
      });

    return pending.take(6).map((item) {
      return <String, dynamic>{
        'id': item.id,
        'title': item.title.trim(),
        'description': item.description,
        'source': 'Daily Planner',
        'module': 'Daily Planner',
        'type': 'daily_planner',
        'time': item.startTime ?? '',
        'start_time': item.startTime ?? '',
        'end_time': item.endTime ?? '',
        'priority': item.priority,
        'is_completed': false,
        'personal_goal_id': item.personalGoalId,
      };
    }).toList();
  }


  List<Map<String, dynamic>> _normaliseTodayFocus(List<dynamic> raw) {
    final items = <Map<String, dynamic>>[];

    String firstNonEmpty(List<dynamic> values) {
      for (final candidate in values) {
        final text = candidate?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    for (final value in raw) {
      if (value is! Map) continue;

      final source = Map<String, dynamic>.from(value);
      final nested = source['item'] is Map
          ? Map<String, dynamic>.from(source['item'] as Map)
          : <String, dynamic>{};

      final completed = source['is_completed'] ??
          source['completed'] ??
          nested['is_completed'] ??
          nested['completed'];
      final status = firstNonEmpty([
        source['status'],
        nested['status'],
      ]).toLowerCase();

      if (completed == true ||
          completed == 1 ||
          completed == '1' ||
          status == 'completed' ||
          status == 'done') {
        continue;
      }

      final title = firstNonEmpty([
        source['title'],
        source['name'],
        source['task'],
        source['subject'],
        source['description'],
        nested['title'],
        nested['name'],
        nested['task'],
      ]);

      if (title.isEmpty) continue;

      items.add({
        ...source,
        'title': title,
        'source': firstNonEmpty([
          source['source'],
          source['type'],
          source['module'],
          source['label'],
          nested['source'],
          'Today',
        ]),
        'time': firstNonEmpty([
          source['time'],
          source['due_time'],
          source['start_time'],
          nested['time'],
          nested['start_time'],
        ]),
      });

      if (items.length >= 6) break;
    }

    return items;
  }

  Future<void> _refreshGrowth() async {
    try {
      final response = await ApiClient.instance.get(
        'growth/dashboard',
        cacheable: false,
      );

      dynamic payload = response;
      if (payload is Map && payload['data'] is Map) {
        payload = payload['data'];
      }

      if (!mounted || payload is! Map) return;

      setState(() {
        _growth = Map<String, dynamic>.from(payload);
      });
    } catch (_) {
      // Growth is an optional enhancement. A missing route must never stop
      // the main dashboard from rendering.
    }
  }

  Future<void> _refreshEngagement() async {
    if (mounted) {
      setState(() => _loadingEngagement = _engagement.isEmpty);
    }

    try {
      final data = await const EngagementService().today();
      if (!mounted) return;
      setState(() {
        _engagement = data;
        _loadingEngagement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEngagement = false);
    }
  }

  Future<void> _startMyDay() async {
    final controller = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            4,
            18,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Start My Day',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the outcome that deserves your best attention today.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'What matters most today?',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.wb_sunny_outlined),
                label: const Text('Start My Day'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      controller.dispose();
      return;
    }

    try {
      await const EngagementService().startDay(
        reflection: controller.text,
      );
      controller.dispose();
      await _refreshEngagement();
    } catch (_) {
      controller.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start your day right now.')),
      );
    }
  }

  Future<void> _closeMyDay() async {
    final reflection = TextEditingController();
    final gratitude = TextEditingController();
    final tomorrow = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            4,
            18,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Close My Day',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Take 60 seconds to close today and prepare tomorrow.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reflection,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'What moved forward today?',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gratitude,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'What are you grateful for?',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tomorrow,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'What should matter first tomorrow?',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.nights_stay_outlined),
                label: const Text('Complete Day Review'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      reflection.dispose();
      gratitude.dispose();
      tomorrow.dispose();
      return;
    }

    try {
      await const EngagementService().closeDay(
        reflection: reflection.text,
        gratitude: gratitude.text,
        tomorrowFocus: tomorrow.text,
      );

      reflection.dispose();
      gratitude.dispose();
      tomorrow.dispose();

      await _refreshEngagement();
    } catch (_) {
      reflection.dispose();
      gratitude.dispose();
      tomorrow.dispose();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not close your day right now.')),
      );
    }
  }

  Future<void> _showEngagementReview(String period) async {
    try {
      final review = await const EngagementService().review(period);
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => EngagementReviewSheet(
          period: period,
          review: review,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load your review.')),
      );
    }
  }

  Future<void> _refreshTodayInsight() async {
    try {
      final response = await ApiClient.instance.get(
        'dashboard/today-insight',
        cacheable: false,
      );

      dynamic payload = response;
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is! Map || payload.isEmpty || !mounted) return;

      final insight = Map<String, dynamic>.from(payload);
      setState(() {
        final next = Map<String, dynamic>.from(_stats ?? const {});
        next['today_insight'] = insight;
        _stats = next;
      });

      _scheduleInsightRefresh(insight['refresh_after']?.toString());
    } catch (_) {
      // Keep the dashboard payload or local time-aware fallback insight.
    }
  }

  void _scheduleInsightRefresh(String? refreshAfter) {
    _insightTimer?.cancel();
    DateTime? next;
    if (refreshAfter != null && refreshAfter.trim().isNotEmpty) {
      next = DateTime.tryParse(refreshAfter)?.toLocal();
    }

    // If the server timestamp cannot be parsed, use the next local two-hour
    // boundary. This keeps Today's Insight changing while Home stays open.
    next ??= (() {
      final now = DateTime.now();
      final nextHour = ((now.hour ~/ 2) + 1) * 2;
      if (nextHour >= 24) {
        return DateTime(now.year, now.month, now.day + 1);
      }
      return DateTime(now.year, now.month, now.day, nextHour);
    })();

    var delay = next.difference(DateTime.now());
    if (delay < const Duration(seconds: 5)) delay = const Duration(seconds: 5);
    _insightTimer = Timer(delay, _refreshTodayInsight);
  }

  Future<void> _refreshFinanceSummary() async {
    try {
      final response = await ApiClient.instance.get(
        'dashboard/finance-summary',
        cacheable: true,
      );
      dynamic finance = response;

      if (finance is Map && finance['data'] is Map) finance = finance['data'];
      if (finance is Map && finance['finance_summary'] is Map) {
        finance = finance['finance_summary'];
      }
      if (finance is! Map || finance.isEmpty || !mounted) return;

      setState(() {
        final next = Map<String, dynamic>.from(_stats ?? const {});
        next['finance_summary'] = Map<String, dynamic>.from(finance as Map);
        _stats = next;
        _applyCurrencyMetadata(finance);
        _currencyCode =
            _extractCurrency(finance) ??
            _extractCurrency(next) ??
            _currencyCode;
      });
    } catch (_) {
      // Finance-at-a-glance can use the values already present in _stats.
    }
  }

  void _applyCurrencyMetadata(dynamic source) {
    if (source is! Map) return;

    dynamic raw = source['display_currency'];
    if (raw is! Map && source['data'] is Map) {
      raw = (source['data'] as Map)['display_currency'];
    }

    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : Map<String, dynamic>.from(source);

    final code = (map['code'] ??
            source['preferred_currency_code'] ??
            source['currency_code'])
        ?.toString()
        .trim()
        .toUpperCase();

    final symbol = (map['symbol'] ?? source['currency_symbol'])
        ?.toString()
        .trim();

    final rateRaw = map['rate'] ?? source['currency_rate'];
    final decimalsRaw = map['decimals'] ?? source['currency_decimals'];

    final rate = rateRaw is num
        ? rateRaw.toDouble()
        : double.tryParse(rateRaw?.toString() ?? '');

    final decimals = decimalsRaw is num
        ? decimalsRaw.toInt()
        : int.tryParse(decimalsRaw?.toString() ?? '');

    if (code != null && code.isNotEmpty) {
      _currencyCode = code;
    }
    if (symbol != null && symbol.isNotEmpty) {
      _currencySymbol = symbol;
    } else {
      _currencySymbol = _currencyCode;
    }
    if (rate != null && rate > 0) {
      _currencyRate = rate;
    }
    if (decimals != null && decimals >= 0 && decimals <= 6) {
      _currencyDecimals = decimals;
    }
  }

  String? _extractCurrency(dynamic source) {
    final seen = <dynamic>{};

    String? normalise(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;

      // Currency codes are normally ISO-4217 (USD, UGX, GBP, EUR, etc.).
      // Keep a few common symbol-only values usable as well.
      final upper = raw.toUpperCase();
      if (RegExp(r'^[A-Z]{3}$').hasMatch(upper)) {
        return upper;
      }

      const symbolMap = <String, String>{
        r'$': 'USD',
        '€': 'EUR',
        '£': 'GBP',
        '¥': 'JPY',
        '₹': 'INR',
      };

      return symbolMap[raw];
    }

    String? scan(dynamic value, [int depth = 0]) {
      if (value == null || depth > 5) return null;

      if (value is Map) {
        if (!seen.add(value)) return null;

        for (final key in const <String>[
          'currency',
          'currency_code',
          'preferred_currency',
          'display_currency',
          'default_currency',
          'user_currency',
        ]) {
          if (value.containsKey(key)) {
            final found = normalise(value[key]);
            if (found != null) return found;
          }
        }

        // Prefer likely preference/profile containers before scanning the rest.
        for (final key in const <String>[
          'user',
          'profile',
          'preferences',
          'personalisation',
          'personalization',
          'settings',
          'finance_summary',
          'financial_health',
          'data',
        ]) {
          if (value.containsKey(key)) {
            final found = scan(value[key], depth + 1);
            if (found != null) return found;
          }
        }

        for (final entry in value.entries) {
          final found = scan(entry.value, depth + 1);
          if (found != null) return found;
        }
      } else if (value is List) {
        for (final item in value.take(10)) {
          final found = scan(item, depth + 1);
          if (found != null) return found;
        }
      }

      return null;
    }

    return scan(source);
  }

  String _firstName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'there';
    return name.split(RegExp(r'\s+')).first;
  }

  List<Map<String, dynamic>> _todaysTopTasks() {
    return List<Map<String, dynamic>>.unmodifiable(_todayFocusItems);
  }

  _DashboardInsight _fallbackInsight() {
    final hour = DateTime.now().hour;

    if (hour < 5 || hour >= 20) {
      return const _DashboardInsight(
        category: 'Evening Reflection',
        title: 'Give today a clear stopping point.',
        message: 'Let unfinished work wait for tomorrow. Reduce unnecessary screen time, notice one thing that went well, and give your mind room to settle.',
        action: 'Review Sleep',
        icon: Icons.nightlight_round,
        background: Color(0xFFF5F3FF),
        foreground: Color(0xFF6D28D9),
        destination: 'sleep',
      );
    }

    if (hour < 10) {
      return const _DashboardInsight(
        category: 'Morning Planning',
        title: 'Choose the few things that deserve your best energy.',
        message: 'Start with your most important outcome, then place the next two priorities around it. A focused morning makes the rest of the day easier to manage.',
        action: 'Plan My Day',
        icon: Icons.wb_sunny_outlined,
        background: Color(0xFFFFFBEB),
        foreground: Color(0xFFB45309),
        destination: 'planner',
      );
    }

    if (hour < 13) {
      return const _DashboardInsight(
        category: 'Productivity',
        title: 'Protect your most productive hours.',
        message: 'Check whether your most important task has moved forward. Give it one uninterrupted block before smaller requests take over the day.',
        action: 'Open Planner',
        icon: Icons.center_focus_strong_outlined,
        background: Color(0xFFFFFBEB),
        foreground: Color(0xFFB45309),
        destination: 'planner',
      );
    }

    if (hour < 17) {
      return const _DashboardInsight(
        category: 'Afternoon Reset',
        title: 'Reset before the second half of your day.',
        message: 'Have some water, move for a few minutes, and close one open loop before taking on another task. A short reset can restore useful focus.',
        action: 'Open Self-care',
        icon: Icons.water_drop_outlined,
        background: Color(0xFFF0F9FF),
        foreground: Color(0xFF0369A1),
        destination: 'wellbeing',
      );
    }

    return const _DashboardInsight(
      category: 'Evening Review',
      title: 'Notice what moved forward today.',
      message: 'Review what you completed, what needs to move, and one thing you handled well. A short review makes tomorrow easier to start.',
      action: 'Open Planner',
      icon: Icons.fact_check_outlined,
      background: Color(0xFFECFDF5),
      foreground: Color(0xFF047857),
      destination: 'planner',
    );
  }

  _DashboardInsight _dailyInsight() {
    final raw = _stats?['today_insight'];
    if (raw is Map) {
      final data = Map<String, dynamic>.from(raw);
      final destination = data['destination']?.toString() ?? 'daily-planner';
      final category = data['category']?.toString() ?? 'Today';
      final palette = _insightPalette(data['tone']?.toString(), category);
      return _DashboardInsight(
        category: category,
        title: data['title']?.toString() ?? 'Make today count.',
        message: data['message']?.toString() ?? 'Choose one useful next step and give it your attention.',
        action: data['action']?.toString() ?? 'Open planner',
        icon: _insightIcon(category, destination),
        background: palette.$1,
        foreground: palette.$2,
        destination: destination,
      );
    }
    return _fallbackInsight();
  }

  (Color, Color) _insightPalette(String? tone, String category) {
    final value = '${tone ?? ''} $category'.toLowerCase();
    if (value.contains('fuchsia') || value.contains('spiritual')) {
      return (const Color(0xFFFDF4FF), const Color(0xFFA21CAF));
    }
    if (value.contains('amber') || value.contains('productivity') || value.contains('budget')) {
      return (const Color(0xFFFFFBEB), const Color(0xFFB45309));
    }
    if (value.contains('violet') || value.contains('indigo') || value.contains('sleep')) {
      return (const Color(0xFFF5F3FF), const Color(0xFF6D28D9));
    }
    if (value.contains('sky') || value.contains('digital')) {
      return (const Color(0xFFF0F9FF), const Color(0xFF0369A1));
    }
    return (const Color(0xFFF0FDFA), const Color(0xFF0F766E));
  }

  IconData _insightIcon(String category, String destination) {
    final value = '$category $destination'.toLowerCase();
    if (value.contains('digital') || value.contains('device')) return Icons.devices_outlined;
    if (value.contains('saving')) return Icons.savings_outlined;
    if (value.contains('expense') || value.contains('budget') || value.contains('financial')) return Icons.account_balance_wallet_outlined;
    if (value.contains('sleep')) return Icons.bedtime_outlined;
    if (value.contains('spiritual')) return Icons.self_improvement_outlined;
    if (value.contains('reminder')) return Icons.notifications_outlined;
    return Icons.auto_awesome_outlined;
  }

  Map<String, dynamic> _financeSummary(String key) {
    dynamic raw = _stats?['finance_summary'];
    if (raw is Map && raw['data'] is Map) raw = raw['data'];
    if (raw is Map && raw[key] is Map) {
      final value = Map<String, dynamic>.from(raw[key] as Map);
      return {
        ...value,
        'title': value['title'] ?? _financeTitle(key),
        'endpoint': value['endpoint'] ?? key,
        'monthly_total': value['monthly_total'] ?? value['month_total'] ?? value['current_month'] ?? 0,
        'overall_total': value['overall_total'] ?? value['total'] ?? value['all_time_total'] ?? 0,
      };
    }

    dynamic pick(List<String> names) {
      for (final name in names) {
        final value = _stats?[name];
        if (value != null) return value;
      }
      return 0;
    }

    switch (key) {
      case 'financial_planner':
        return {
          'title': 'Financial Planner',
          'endpoint': 'financial-planner',
          'monthly_total': pick(['monthly_net', 'net_position', 'monthly_savings']),
          'overall_total': pick(['overall_net', 'net_position', 'monthly_savings']),
          'monthly_label': 'Net this month',
          'overall_label': 'Current position',
        };
      case 'income':
        return {'title': 'Income', 'endpoint': 'incomes', 'monthly_total': pick(['monthly_income', 'income_month']), 'overall_total': pick(['total_income', 'overall_income', 'monthly_income'])};
      case 'expenses':
        return {'title': 'Expenses', 'endpoint': 'expenses', 'monthly_total': pick(['monthly_expenses', 'expense_month']), 'overall_total': pick(['total_expenses', 'overall_expenses', 'monthly_expenses'])};
      case 'budgets':
        return {'title': 'Budgets', 'endpoint': 'budgets', 'monthly_total': pick(['monthly_budget', 'budget_month']), 'overall_total': pick(['total_budget', 'overall_budget', 'monthly_budget'])};
      case 'debts':
        return {'title': 'Debts', 'endpoint': 'debts', 'monthly_total': pick(['monthly_debts', 'debt_month']), 'overall_total': pick(['total_debts', 'outstanding_debt'])};
      case 'savings':
        return {'title': 'Savings', 'endpoint': 'savings', 'monthly_total': pick(['monthly_savings', 'saved_month']), 'overall_total': pick(['total_savings', 'overall_savings', 'monthly_savings'])};
      case 'savings_goals':
        return {'title': 'Savings Goals', 'endpoint': 'savings-goals', 'monthly_total': pick(['monthly_goal_contributions', 'monthly_savings']), 'overall_total': pick(['savings_goal_total', 'total_savings_goals'])};
      default:
        return const {};
    }
  }

  String _financeTitle(String key) {
    switch (key) {
      case 'financial_planner': return 'Financial Planner';
      case 'income': return 'Income';
      case 'expenses': return 'Expenses';
      case 'budgets': return 'Budgets';
      case 'debts': return 'Debts';
      case 'savings': return 'Savings';
      case 'savings_goals': return 'Savings Goals';
      default: return 'Finance';
    }
  }

  List<String> _availableFinanceKeys() {
    return const <String>[
      'income',
      'expenses',
      'budgets',
      'savings',
      'debts',
      'savings_goals',
    ];
  }

  void _openFinance(String key) {
    if (key == 'budgets') {
      _open(const BudgetsScreen());
      return;
    }

    final summary = _financeSummary(key);
    if (summary.isEmpty) return;

    _open(
      FinanceReportScreen(
        endpoint: summary['endpoint']?.toString() ?? key,
        title: summary['title']?.toString() ?? key,
        initialSummary: summary,
      ),
    );
  }

  void _openInsight(_DashboardInsight insight) {
    switch (insight.destination) {
      case 'financial':
        _open(const FinancialPlannerScreen());
        break;
      case 'health':
        _openModule('health-checkups');
        break;
      case 'planner':
        _open(const DailyPlannerScreen());
        break;
      case 'network':
        _openModule('network-contacts');
        break;
      case 'education':
        _openModule('education-plans');
        break;
      case 'spiritual':
        _openModule('spiritual-practices');
        break;
      case 'annual':
        _open(const AnnualPlansScreen());
        break;
      case 'expenses':
        _openFinance('expenses');
        break;
      case 'budgets':
        _open(const BudgetsScreen());
        break;
      case 'savings-goals':
        _openFinance('savings_goals');
        break;
      case 'project-tasks':
        _openModule('project-tasks');
        break;
      case 'reminders':
        _open(const RemindersScreen());
        break;
      case 'daily-planner':
        _open(const DailyPlannerScreen());
        break;
      case 'sleep-logs':
        _openModule('sleep-logs');
        break;
      case 'spiritual-practices':
        _openModule('spiritual-practices');
        break;
      case 'personal-goals':
        _openModule('personal-goals');
        break;
      case 'wellbeing':
        _openModule('wellbeing');
        break;
    }
  }

  Future<void> _toggleAlarmMute() async {
    try {
      final muted = await ReminderAlarmService().toggleMute();
      if (!mounted) return;
      context.read<AuthService>().updateAlarmsMuted(muted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(muted ? 'Reminder alarms muted.' : 'Reminder alarms unmuted.')),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _openPlannerAndRefresh() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DailyPlannerScreen(),
      ),
    );

    if (!mounted) return;
    await _refreshTodayFocusFromPlanner();
  }

  Future<void> _openPersonalisation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PersonalisationScreen(),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  void _openModule(String endpoint) {
    final config = moduleConfigByEndpoint(endpoint);
    _open(DynamicCrudScreen(config: config));
  }

  Widget _buildTodayFocusSection() {
    final items = _todaysTopTasks();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionHeading(
                title: "Today's focus",
                icon: Icons.wb_sunny_outlined,
              ),
            ),
            TextButton.icon(
              onPressed: _openPlannerAndRefresh,
              icon: const Icon(Icons.today_outlined, size: 16),
              label: const Text('Planner'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_loadingTodayFocus && items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text('Loading today’s tasks…', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600))),
              ],
            ),
          )
        else if (items.isNotEmpty)
          ...[for (var i = 0; i < items.length; i++) _TodayTask(index: i + 1, task: items[i])]
        else if (_todayFocusError != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Today’s Focus could not refresh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                      const SizedBox(height: 3),
                      Text(_todayFocusError!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(onPressed: _load, tooltip: 'Retry', icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              leading: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF0F9D8A)),
              title: const Text('No pending focus items for today.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: const Text('Pending Daily Planner tasks due today will appear here. Pull down to refresh after making changes.', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: _openPlannerAndRefresh,
            ),
          ),

        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _open(const RecentActivityScreen()),
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('Recent activity'),
          ),
        ),
      ],
    );
  }

  Widget _buildNextBestActionsSection() {
    final widgets = <Widget>[
      const SizedBox(height: 18),
      Row(
        children: [
          const Expanded(
            child: _SectionHeading(
              title: 'Next best actions',
              icon: Icons.explore_outlined,
            ),
          ),
          TextButton(
            onPressed: () => _open(const GoalIntelligenceScreen()),
            child: const Text('View goals'),
          ),
        ],
      ),
    ];

    final rawGoal = _stats?['goal_intelligence'];
    List<dynamic> actions = const <dynamic>[];
    if (rawGoal is Map) {
      final goal = Map<String, dynamic>.from(rawGoal);
      final rawActions = goal['next_actions'];
      if (rawActions is List) actions = rawActions;
    }

    var count = 0;
    for (final raw in actions) {
      if (raw is! Map) continue;
      final a = Map<String, dynamic>.from(raw);
      final title = (a['title'] ?? a['name'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final message = (a['message'] ?? a['description'] ?? 'Review this goal and choose one useful next step.').toString().trim();
      final state = (a['state'] ?? a['status'] ?? '').toString().toLowerCase();

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Icon(
                state == 'overdue' || state == 'at_risk'
                    ? Icons.warning_amber_rounded
                    : Icons.trending_up_rounded,
                color: state == 'overdue' || state == 'at_risk'
                    ? const Color(0xFFD97706)
                    : const Color(0xFF0F9D8A),
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              subtitle: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _open(const GoalIntelligenceScreen()),
            ),
          ),
        ),
      );

      count++;
      if (count >= 3) break;
    }

    if (count == 0) {
      widgets.add(
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: const Icon(Icons.track_changes_outlined, color: Color(0xFF7C3AED)),
            title: const Text(
              'No urgent goal actions right now.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            subtitle: const Text(
              'Open Goals to review progress or choose your next action.',
              style: TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _open(const GoalIntelligenceScreen()),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget _buildToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const _SectionHeading(
          title: 'Tools',
          icon: Icons.grid_view_rounded,
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 6,
          childAspectRatio: .9,
          children: [
            _AppleIconTile(
              title: 'Sign',
              icon: Icons.draw_outlined,
              background: const Color(0xFFEEF2FF),
              foreground: const Color(0xFF4338CA),
              onTap: () => _open(const SignaturesScreen()),
            ),
            _AppleIconTile(
              title: 'My Card',
              icon: Icons.badge_outlined,
              background: const Color(0xFFF0FDFA),
              foreground: const Color(0xFF0F766E),
              onTap: () => _open(const BusinessCardScreen()),
            ),
            _AppleIconTile(
              title: 'Notes',
              icon: Icons.note_alt_outlined,
              background: const Color(0xFFFFFBEB),
              foreground: const Color(0xFFB45309),
              onTap: () => _openModule('notes'),
            ),
            _AppleIconTile(
              title: 'AI Planner',
              icon: Icons.auto_awesome,
              background: const Color(0xFFF5F3FF),
              foreground: const Color(0xFF6D28D9),
              onTap: () => _open(const AiPlannerScreen()),
            ),
            _AppleIconTile(
              title: 'Social',
              icon: Icons.campaign_outlined,
              background: const Color(0xFFF0F9FF),
              foreground: const Color(0xFF0369A1),
              onTap: () => _open(const SocialMediaPlannerScreen()),
            ),
            _AppleIconTile(
              title: 'Finance',
              icon: Icons.account_balance_wallet_outlined,
              background: const Color(0xFFECFDF5),
              foreground: const Color(0xFF047857),
              onTap: () => _open(const FinancialPlannerScreen()),
            ),
            _AppleIconTile(
              title: 'Expenses',
              icon: Icons.receipt_long_outlined,
              background: const Color(0xFFFFF1F2),
              foreground: const Color(0xFFBE123C),
              onTap: () => _open(const ExpensesScreen()),
            ),
            _AppleIconTile(
              title: 'Education',
              icon: Icons.school_outlined,
              background: const Color(0xFFEEF2FF),
              foreground: const Color(0xFF4338CA),
              onTap: () => _openModule('education-plans'),
            ),
            _AppleIconTile(
              title: 'Contacts',
              icon: Icons.contacts_outlined,
              background: const Color(0xFFF0F9FF),
              foreground: const Color(0xFF0369A1),
              onTap: () => _openModule('network-contacts'),
            ),
            _AppleIconTile(
              title: 'Spiritual',
              icon: Icons.self_improvement_outlined,
              background: const Color(0xFFFDF4FF),
              foreground: const Color(0xFFA21CAF),
              onTap: () => _openModule('spiritual-practices'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinanceSection() {
    final keys = _availableFinanceKeys();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const _SectionHeading(
          title: 'Finance at a glance',
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 10),
        GridView.builder(
          itemCount: keys.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 146,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final key = keys[index];
            final summary = _financeSummary(key);
            return _FinanceCard(
              summary: summary,
              currencyCode:
                  _extractCurrency(summary) ?? _currencyCode,
              currencySymbol: _currencySymbol,
              currencyRate: _currencyRate,
              currencyDecimals: _currencyDecimals,
              onTap: () => key == 'financial_planner'
                  ? _open(const FinancialPlannerScreen())
                  : _openFinance(key),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final dailyInsight = _dailyInsight();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${_firstName(auth.user?.name)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => _open(const SearchScreen()),
          ),
          IconButton(
            icon: Icon(auth.user?.alarmsMuted == true
                ? Icons.notifications_off
                : Icons.notifications_active),
            tooltip: auth.user?.alarmsMuted == true
                ? 'Unmute reminders'
                : 'Mute reminders',
            onPressed: _toggleAlarmMute,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshHome,
        child: CustomScrollView(
          controller: _dashboardScrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                14,
                8,
                14,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
            if (_loading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 8),
            ],
            _WelcomeCard(name: _firstName(auth.user?.name)),
            const SizedBox(height: 12),
            EngagementDashboardSection(
              data: _engagement,
              loading: _loadingEngagement,
              onStartDay: _startMyDay,
              onCloseDay: _closeMyDay,
              onWeekReview: () => _showEngagementReview('week'),
              onMonthReview: () => _showEngagementReview('month'),
            ),
            if (_growth.isNotEmpty) ...[
              const SizedBox(height: 12),
              _GrowthStrategyCard(
                data: _growth,
                onRefresh: _refreshGrowth,
              ),
            ],
            if (_stats?['onboarding'] is Map &&
                (Map<String, dynamic>.from(_stats!['onboarding'] as Map)['completed'] != true)) ...[
              const SizedBox(height: 10),
              _GettingStartedCard(
                onTap: _openPersonalisation,
              ),
            ],
            const SizedBox(height: 14),
            if (_stats?['personal_progress'] is Map) ...[
              _ProgressOverview(
                progress: Map<String, dynamic>.from(
                  _stats!['personal_progress'] as Map,
                ),
                currencyCode: _currencyCode,
                currencySymbol: _currencySymbol,
                currencyRate: _currencyRate,
                currencyDecimals: _currencyDecimals,
                onFinancialHealth: () => _open(const FinancialPlannerScreen()),
                onWeekReview: () => _open(const RecentActivityScreen()),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _open(const MonthlyReviewScreen()),
                  icon: const Icon(Icons.calendar_view_month_outlined, size: 18),
                  label: const Text('My Month in Review'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const _SectionHeading(title: 'Start here', icon: Icons.bolt_rounded),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 6,
              childAspectRatio: .9,
              children: [
                _AppleIconTile(title: 'Planner', icon: Icons.today_outlined, background: const Color(0xFFECFDF5), foreground: const Color(0xFF047857), onTap: () => _open(const DailyPlannerScreen())),
                _AppleIconTile(title: 'Reminders', icon: Icons.notifications_outlined, background: const Color(0xFFFFFBEB), foreground: const Color(0xFFB45309), onTap: () => _open(const RemindersScreen())),
                _AppleIconTile(title: 'Meetings', icon: Icons.video_camera_front_outlined, background: const Color(0xFFF5F3FF), foreground: const Color(0xFF6D28D9), onTap: () => _open(const MeetingsScreen())),
                _AppleIconTile(title: 'Plans', icon: Icons.event_note_outlined, background: const Color(0xFFEFF6FF), foreground: const Color(0xFF1D4ED8), onTap: () => _open(const AnnualPlansScreen())),
                _AppleIconTile(title: 'Projects', icon: Icons.account_tree_outlined, background: const Color(0xFFF0F9FF), foreground: const Color(0xFF0369A1), onTap: () => _openModule('projects')),
                _AppleIconTile(title: 'Health', icon: Icons.favorite_border, background: const Color(0xFFFFF1F2), foreground: const Color(0xFFBE123C), onTap: () => _openModule('health-checkups')),
                _AppleIconTile(title: 'Goals', icon: Icons.track_changes_outlined, background: const Color(0xFFF5F3FF), foreground: const Color(0xFF6D28D9), onTap: () => _openModule('personal-goals')),
                _AppleIconTile(title: 'Self-care', icon: Icons.water_drop_outlined, background: const Color(0xFFECFEFF), foreground: const Color(0xFF0F766E), onTap: () => _openModule('wellbeing')),
              ],
            ),
            const SizedBox(height: 18),
            _buildTodayFocusSection(),
            _buildNextBestActionsSection(),
            _buildToolsSection(),
            const SizedBox(height: 18),
            _DailyInsightCard(
              insight: dailyInsight,
              onTap: () => _openInsight(dailyInsight),
            ),
            _buildFinanceSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _GrowthStrategyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;

  const _GrowthStrategyCard({
    required this.data,
    required this.onRefresh,
  });

  Map<String, dynamic> _map(String key) {
    final raw = data[key];
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final activation = _map('activation');
    final challenge = _map('challenge');
    final trust = _map('trust');

    final percent = ((activation['percent'] as num?)?.toDouble() ?? 0)
        .clamp(0, 100);
    final challengePercent =
        ((challenge['progress_percent'] as num?)?.toDouble() ?? 0)
            .clamp(0, 100);
    final joined = challenge['joined'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TAKE BACK YOUR ATTENTION',
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: .65,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Build your own progress, not just your feed.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Private',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),

          if (activation.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'First value · ${activation['completed'] ?? 0}/${activation['total'] ?? 3}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${percent.round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 13),
          ],

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '30 DAYS WITH MY DIGITAL DIARY',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: .45,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6D28D9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (challenge['title'] ??
                          '30 Days With My Digital Diary')
                      .toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Plan, act, record and reflect consistently.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (joined) ...[
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: challengePercent / 100,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${challenge['meaningful_days'] ?? 0} meaningful day(s)',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 9),

          Text(
            (trust['message'] ??
                    'Private diary content is never included in shared progress cards.')
                .toString(),
            style: const TextStyle(
              fontSize: 9.8,
              height: 1.35,
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onRefresh(),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
              ),
              label: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }
}


class _ProgressOverview extends StatelessWidget {
  final Map<String, dynamic> progress;
  final String currencyCode;
  final String currencySymbol;
  final double currencyRate;
  final int currencyDecimals;
  final VoidCallback? onFinancialHealth;
  final VoidCallback? onWeekReview;

  const _ProgressOverview({
    required this.progress,
    required this.currencyCode,
    required this.currencySymbol,
    required this.currencyRate,
    required this.currencyDecimals,
    this.onFinancialHealth,
    this.onWeekReview,
  });

  String _money(dynamic value) {
    final baseAmount = value is num
        ? value.toDouble()
        : double.tryParse(
              value?.toString().replaceAll(',', '').trim() ?? '',
            ) ??
            0;

    // Laravel stores finance amounts in the base currency. Admin currency
    // rates are base-currency units per 1 display-currency unit, matching
    // SiteSetting::convertBaseAmount().
    final rate = currencyRate > 0 ? currencyRate : 1.0;
    final converted = baseAmount / rate;
    final decimals = currencyDecimals.clamp(0, 6).toInt();
    final fixed = converted.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    final formatted = decimals > 0 && parts.length > 1
        ? '$whole.${parts[1]}'
        : whole;

    final prefix = currencySymbol.trim().isNotEmpty
        ? currencySymbol.trim()
        : currencyCode.trim().toUpperCase();

    return '${prefix.isEmpty ? 'UGX' : prefix} $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final finance = Map<String, dynamic>.from((progress['financial_health'] as Map?) ?? const {});
    final week = Map<String, dynamic>.from((progress['weekly_review'] as Map?) ?? const {});

    Widget progressCard({required Widget child, required Color accent, VoidCallback? onTap}) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(child: Padding(padding: const EdgeInsets.all(14), child: child)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Your progress', icon: Icons.insights_outlined),
        const SizedBox(height: 10),
        progressCard(
          accent: const Color(0xFF0F766E),
          onTap: onFinancialHealth,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Financial Health', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${finance['score'] ?? 0}/100 · ${finance['label'] ?? 'Start tracking'}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ])),
              const CircleAvatar(backgroundColor: Color(0xFFCCFBF1), foregroundColor: Color(0xFF0F766E), child: Icon(Icons.trending_up)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _MiniMetric(label: 'Income', value: _money(finance['monthly_income']))),
              Expanded(child: _MiniMetric(label: 'Expenses', value: _money(finance['monthly_expenses']))),
              Expanded(child: _MiniMetric(label: 'Saved', value: _money(finance['monthly_savings']))),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        progressCard(
          accent: const Color(0xFF7C3AED),
          onTap: onWeekReview,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your Week in Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text('${week['completion_percent'] ?? 0}% task completion', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ])),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ]),
            if ((week['period'] ?? '').toString().isNotEmpty) Text(week['period'].toString(), style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 12),
            Wrap(spacing: 18, runSpacing: 10, children: [
              _MiniMetric(label: 'Tasks', value: '${week['completed_tasks'] ?? 0}/${week['total_tasks'] ?? 0}'),
              _MiniMetric(label: 'Spent', value: _money(week['expenses'])),
              _MiniMetric(label: 'Saved', value: _money(week['saved'])),
              _MiniMetric(label: 'Exercise', value: '${week['exercise_sessions'] ?? 0} sessions'),
            ]),
          ]),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  const _MiniMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
  ]);
}

class _GettingStartedCard extends StatelessWidget {
  final VoidCallback onTap;
  const _GettingStartedCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0FDFA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(backgroundColor: Color(0xFFCCFBF1), child: Icon(Icons.tune_rounded, color: Color(0xFF0F766E))),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Make My Digital Diary yours', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 3),
              Text('Choose what matters most and what AI Planner may use.', style: TextStyle(fontSize: 12, color: Colors.black54)),
            ])),
            Icon(Icons.chevron_right, color: Color(0xFF0F766E)),
          ]),
        ),
      ),
    );
  }
}

class _DashboardInsight {
  final String category;
  final String title;
  final String message;
  final String action;
  final IconData icon;
  final Color background;
  final Color foreground;
  final String destination;

  const _DashboardInsight({
    required this.category,
    required this.title,
    required this.message,
    required this.action,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.destination,
  });
}

class _DailyInsightCard extends StatelessWidget {
  final _DashboardInsight insight;
  final VoidCallback onTap;

  const _DailyInsightCard({required this.insight, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: insight.background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: insight.foreground.withValues(alpha: .18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(insight.icon, color: insight.foreground, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TODAY’S INSIGHT', style: TextStyle(fontSize: 10.5, letterSpacing: .7, fontWeight: FontWeight.w800, color: insight.foreground)),
                        const SizedBox(height: 2),
                        Text(insight.category, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  const Text('Refreshes ~2h', style: TextStyle(fontSize: 11, color: Colors.black45)),
                ],
              ),
              const SizedBox(height: 14),
              Text(insight.title, style: const TextStyle(fontSize: 17, height: 1.25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(insight.message, style: TextStyle(fontSize: 13, height: 1.45, color: Colors.grey.shade700)),
              const SizedBox(height: 13),
              Row(
                children: [
                  Text(insight.action, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: insight.foreground)),
                  const SizedBox(width: 5),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: insight.foreground),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final String currencyCode;
  final String currencySymbol;
  final double currencyRate;
  final int currencyDecimals;
  final VoidCallback onTap;

  const _FinanceCard({
    required this.summary,
    required this.currencyCode,
    required this.currencySymbol,
    required this.currencyRate,
    required this.currencyDecimals,
    required this.onTap,
  });

  String _money(dynamic value) {
    final baseAmount = value is num
        ? value.toDouble()
        : double.tryParse(
              value?.toString().replaceAll(',', '').trim() ?? '',
            ) ??
            0;

    final rate = currencyRate > 0 ? currencyRate : 1.0;
    final converted = baseAmount / rate;
    final decimals = currencyDecimals.clamp(0, 6).toInt();
    final fixed = converted.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    final formatted = decimals > 0 && parts.length > 1
        ? '$whole.${parts[1]}'
        : whole;

    final prefix = currencySymbol.trim().isNotEmpty
        ? currencySymbol.trim()
        : currencyCode.trim().toUpperCase();

    return '${prefix.isEmpty ? 'UGX' : prefix} $formatted';
  }

  (Color, Color, IconData) _style(String title) {
    final key = title.toLowerCase();
    if (key.contains('income')) return (const Color(0xFFEAFBF3), const Color(0xFF047857), Icons.trending_up_rounded);
    if (key.contains('expense')) return (const Color(0xFFFFEEF1), const Color(0xFFBE123C), Icons.receipt_long_outlined);
    if (key.contains('budget')) return (const Color(0xFFEDF5FF), const Color(0xFF1D4ED8), Icons.account_balance_wallet_outlined);
    if (key.contains('saving')) return (const Color(0xFFF4F0FF), const Color(0xFF6D28D9), Icons.savings_outlined);
    if (key.contains('debt')) return (const Color(0xFFFFF3E8), const Color(0xFFC2410C), Icons.credit_card_outlined);
    return (const Color(0xFFECFAFC), const Color(0xFF0E7490), Icons.flag_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final title = (summary['title'] ?? 'Finance').toString();
    final monthlyLabel = (summary['monthly_label'] ?? 'This month').toString();
    final overallLabel = (summary['overall_label'] ?? 'Overall').toString();
    final style = _style(title);

    return Semantics(
      button: true,
      label: '$title finance report',
      child: Material(
        color: style.$1,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 140),
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: style.$2, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Icon(style.$3, color: style.$2, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800, fontSize: 13))),
                  Icon(Icons.chevron_right_rounded, color: style.$2, size: 18),
                ]),
                const SizedBox(height: 10),
                Text(monthlyLabel, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(_money(summary['monthly_total']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111827), fontSize: 14, height: 1.15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('$overallLabel: ${_money(summary['overall_total'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF475569), fontSize: 10.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;
  const _WelcomeCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: const [BoxShadow(color: Color(0x120F172A), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Digital Diary', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 5),
          Text('What would you like to do today?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('Everything important is one tap away.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeading({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ShortcutCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  State<_ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<_ShortcutCard> {
  bool _pressed = false;

  Widget _animatedSubtitle() {
    final match = RegExp(r'^([0-9]+)(.*)$').firstMatch(widget.subtitle.trim());
    if (match == null) {
      return Text(widget.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)));
    }
    final target = int.tryParse(match.group(1) ?? '') ?? 0;
    final suffix = match.group(2) ?? '';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => Text(
        '${value.round()}$suffix',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final scale = _pressed && !reduceMotion ? .965 : 1.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : .96, end: 1),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, entryScale, child) => Transform.scale(scale: entryScale * scale, child: child),
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: widget.foreground.withValues(alpha: _pressed ? .28 : .16)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: _pressed ? .045 : .075),
              blurRadius: _pressed ? 10 : 18,
              offset: Offset(0, _pressed ? 4 : 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedRotation(
                    turns: _pressed && !reduceMotion ? -.018 : 0,
                    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                    child: AnimatedScale(
                      scale: _pressed && !reduceMotion ? .9 : 1,
                      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: widget.foreground.withValues(alpha: .14)),
                        ),
                        child: Icon(widget.icon, color: widget.foreground, size: 21),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 3),
                      _animatedSubtitle(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppleIconTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _AppleIconTile({
    required this.title,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: foreground.withValues(alpha: .12)),
                  boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Icon(icon, color: foreground, size: 21),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, height: 1.1, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayTask extends StatelessWidget {
  final int index;
  final Map<String, dynamic> task;
  const _TodayTask({required this.index, required this.task});

  @override
  Widget build(BuildContext context) {
    const accents = [
      Color(0xFF0F9D8A),
      Color(0xFF7C3AED),
      Color(0xFFD97706),
      Color(0xFF2563EB),
    ];
    final accent = accents[(index - 1) % accents.length];
    final title = (task['title'] ?? '').toString().trim();
    final source = (task['source'] ?? 'Today').toString().trim();
    final time = (task['time'] ?? '').toString().trim();
    final sourceLower = source.toLowerCase();

    if (title.isEmpty) return const SizedBox.shrink();

    final icon = sourceLower.contains('meeting')
        ? Icons.videocam_outlined
        : sourceLower.contains('reminder')
            ? Icons.notifications_none_rounded
            : sourceLower.contains('planner')
                ? Icons.today_outlined
                : Icons.task_alt_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x100F172A), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accent, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                source.isEmpty ? 'TODAY' : source.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .25,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              if (time.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      time,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
