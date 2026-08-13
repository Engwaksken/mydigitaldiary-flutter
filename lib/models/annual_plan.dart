class AnnualPlan {
  final int id;
  final String title;
  final String? description;
  final int year;
  final DateTime? targetDate;
  final int progressPercent;
  final bool isCompleted;

  const AnnualPlan({
    required this.id,
    required this.title,
    this.description,
    required this.year,
    this.targetDate,
    required this.progressPercent,
    required this.isCompleted,
  });

  factory AnnualPlan.fromJson(Map<String, dynamic> json) {
    final progress = (json['progress_percent'] as num?)?.toInt() ?? 0;
    final status = json['status']?.toString();
    return AnnualPlan(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      year: (json['plan_year'] as num?)?.toInt() ?? DateTime.now().year,
      targetDate: json['target_date'] == null ? null : DateTime.tryParse(json['target_date'].toString()),
      progressPercent: progress.clamp(0, 100).toInt(),
      isCompleted: status == 'completed' || progress >= 100,
    );
  }
}

class AnnualPlanSummary {
  final int year;
  final int total;
  final int completed;
  final int overallProgress;
  final List<int> availableYears;
  final List<AnnualPlan> plans;

  const AnnualPlanSummary({
    required this.year,
    required this.total,
    required this.completed,
    required this.overallProgress,
    required this.availableYears,
    required this.plans,
  });

  factory AnnualPlanSummary.fromJson(Map<String, dynamic> json) {
    final rows = (json['plans'] as List? ?? const [])
        .map((e) => AnnualPlan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return AnnualPlanSummary(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      total: (json['total'] as num?)?.toInt() ?? rows.length,
      completed: (json['completed'] as num?)?.toInt() ?? rows.where((p) => p.isCompleted).length,
      overallProgress: ((json['overall_progress'] as num?)?.toInt() ?? 0).clamp(0, 100).toInt(),
      availableYears: (json['available_years'] as List? ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      plans: rows,
    );
  }
}
