int _annualInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
}

class AnnualPlan {
  final int id;
  final String title;
  final String? description;
  final int year;
  final String period;
  final int? month;
  final DateTime? targetDate;
  final DateTime? reminderAt;
  final int progressPercent;
  final String status;
  final bool isCompleted;
  final int? personalGoalId;

  const AnnualPlan({
    required this.id,
    required this.title,
    this.description,
    required this.year,
    required this.period,
    this.month,
    this.targetDate,
    this.reminderAt,
    required this.progressPercent,
    required this.status,
    required this.isCompleted,
    this.personalGoalId,
  });

  factory AnnualPlan.fromJson(Map<String, dynamic> json) {
    final progress = _annualInt(json['progress_percent']);
    final status = json['status']?.toString() ?? 'in_progress';
    return AnnualPlan(
      id: _annualInt(json['id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      year: _annualInt(json['plan_year'], DateTime.now().year),
      period: json['period']?.toString() ?? 'annually',
      month: json['plan_month'] == null ? null : _annualInt(json['plan_month']),
      targetDate: json['target_date'] == null
          ? null
          : DateTime.tryParse(json['target_date'].toString()),
      reminderAt: json['reminder_at'] == null
          ? null
          : DateTime.tryParse(json['reminder_at'].toString()),
      progressPercent: progress.clamp(0, 100).toInt(),
      status: status,
      isCompleted: status == 'completed' || progress >= 100,
      personalGoalId: json['personal_goal_id'] == null
          ? null
          : _annualInt(json['personal_goal_id']),
    );
  }
}

class AnnualPlanSummary {
  final int year;
  final int total;
  final int completed;
  final int monthly;
  final int withReminder;
  final int overallProgress;
  final List<int> availableYears;
  final List<AnnualPlan> plans;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int filteredTotal;
  final int from;
  final int to;

  const AnnualPlanSummary({
    required this.year,
    required this.total,
    required this.completed,
    required this.monthly,
    required this.withReminder,
    required this.overallProgress,
    required this.availableYears,
    required this.plans,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.filteredTotal,
    required this.from,
    required this.to,
  });

  factory AnnualPlanSummary.fromJson(Map<String, dynamic> json) {
    final rows = (json['plans'] as List? ?? const [])
        .map((e) => AnnualPlan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final p =
        Map<String, dynamic>.from((json['pagination'] as Map?) ?? const {});
    return AnnualPlanSummary(
      year: _annualInt(json['year'], DateTime.now().year),
      total: _annualInt(json['total'], rows.length),
      completed: _annualInt(
          json['completed'], rows.where((e) => e.isCompleted).length),
      monthly: _annualInt(
          json['monthly'], rows.where((e) => e.period == 'monthly').length),
      withReminder: _annualInt(json['with_reminder'],
          rows.where((e) => e.reminderAt != null).length),
      overallProgress:
          _annualInt(json['overall_progress']).clamp(0, 100).toInt(),
      availableYears: (json['available_years'] as List? ?? const [])
          .map((e) => _annualInt(e))
          .toList(),
      plans: rows,
      currentPage: _annualInt(p['current_page'], 1),
      lastPage: _annualInt(p['last_page'], 1),
      perPage: _annualInt(p['per_page'], 10),
      filteredTotal: _annualInt(p['total'], rows.length),
      from: _annualInt(p['from'], rows.isEmpty ? 0 : 1),
      to: _annualInt(p['to'], rows.length),
    );
  }
}
