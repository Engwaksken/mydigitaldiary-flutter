class DailyPlanItem {
  final int id;
  final String title;
  final String? description;
  final String priority;
  final String? startTime;
  final String? endTime;
  final bool isCompleted;
  final DateTime? completedAt;

  const DailyPlanItem({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    this.startTime,
    this.endTime,
    required this.isCompleted,
    this.completedAt,
  });

  factory DailyPlanItem.fromJson(Map<String, dynamic> json) => DailyPlanItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString(),
        priority: json['priority']?.toString() ?? 'medium',
        startTime: json['start_time']?.toString(),
        endTime: json['end_time']?.toString(),
        isCompleted: json['is_completed'] == true || json['is_completed'] == 1,
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'].toString())?.toLocal()
            : null,
      );
}

class DailyPlan {
  final int id;
  final DateTime date;
  final String title;
  final String? notes;
  final int total;
  final int completed;
  final int progress;
  final int timed;
  final List<DailyPlanItem> items;

  const DailyPlan({
    required this.id,
    required this.date,
    required this.title,
    this.notes,
    required this.total,
    required this.completed,
    required this.progress,
    required this.timed,
    required this.items,
  });

  int get pending => total - completed;

  factory DailyPlan.fromJson(Map<String, dynamic> json) {
    final planRaw = json['plan'];
    final plan = planRaw is Map
        ? planRaw.cast<String, dynamic>()
        : <String, dynamic>{};
    final rawItems = (json['items'] ?? plan['items'] ?? const []) as List;
    final rows = rawItems
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final dateValue = plan['plan_date'] ?? json['date'] ?? json['plan_date'];

    return DailyPlan(
      id: (plan['id'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(dateValue?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      title: plan['title']?.toString() ?? 'My Daily Plan',
      notes: plan['notes']?.toString(),
      total: (json['total'] as num?)?.toInt() ?? rows.length,
      completed: (json['completed'] as num?)?.toInt() ??
          rows.where((e) => e['is_completed'] == true || e['is_completed'] == 1).length,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      timed: (json['timed'] as num?)?.toInt() ??
          rows.where((e) => (e['start_time']?.toString().isNotEmpty ?? false)).length,
      items: rows.map(DailyPlanItem.fromJson).toList(),
    );
  }
}

class DailyPlanHistoryItem {
  final int id;
  final DateTime date;
  final String title;
  final String? notes;
  final int total;
  final int completed;
  final int progress;

  const DailyPlanHistoryItem({
    required this.id,
    required this.date,
    required this.title,
    this.notes,
    required this.total,
    required this.completed,
    required this.progress,
  });

  factory DailyPlanHistoryItem.fromJson(Map<String, dynamic> json) => DailyPlanHistoryItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        date: DateTime.parse(json['plan_date'].toString()).toLocal(),
        title: json['title']?.toString() ?? 'My Daily Plan',
        notes: json['notes']?.toString(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
      );
}

class DailyPlanHistoryPage {
  final List<DailyPlanHistoryItem> data;
  final int currentPage;
  final int lastPage;
  final int total;

  const DailyPlanHistoryPage({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  factory DailyPlanHistoryPage.fromJson(Map<String, dynamic> json) {
    final raw = (json['data'] as List? ?? const []);
    return DailyPlanHistoryPage(
      data: raw
          .whereType<Map>()
          .map((e) => DailyPlanHistoryItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? raw.length,
    );
  }
}
