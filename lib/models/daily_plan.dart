int _dailyInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
}

bool _dailyBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase().trim();
  return text == '1' || text == 'true' || text == 'yes';
}

class DailyPlanItem {
  final int id;
  final String title;
  final String? description;
  final String? achievements;
  final String? challenges;
  final String priority;
  final String? startTime;
  final String? endTime;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? updatedAt;
  final bool offlinePending;
  final int? personalGoalId;

  const DailyPlanItem({
    required this.id,
    required this.title,
    this.description,
    this.achievements,
    this.challenges,
    required this.priority,
    this.startTime,
    this.endTime,
    required this.isCompleted,
    this.completedAt,
    this.updatedAt,
    this.offlinePending = false,
    this.personalGoalId,
  });

  factory DailyPlanItem.fromJson(Map<String, dynamic> json) => DailyPlanItem(
        id: _dailyInt(json['id']),
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString(),
      achievements: json['achievements']?.toString(),
      challenges: json['challenges']?.toString(),
        priority: json['priority']?.toString() ?? 'medium',
        startTime: json['start_time']?.toString(),
        endTime: json['end_time']?.toString(),
        isCompleted: _dailyBool(json['is_completed']),
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'].toString())?.toLocal()
            : null,
        updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() : null,
        offlinePending: json['_offline_pending'] == true,
        personalGoalId: json['personal_goal_id'] == null ? null : _dailyInt(json['personal_goal_id']),
      );
}

class DailyPlan {
  final int id;
  final DateTime date;
  final String title;
  final String? notes;
  final String? achievements;
  final String? challenges;
  final int total;
  final int completed;
  final int progress;
  final int timed;
  final List<DailyPlanItem> items;
  final DateTime? updatedAt;
  final bool offlinePending;

  const DailyPlan({
    required this.id,
    required this.date,
    required this.title,
    this.notes,
    this.achievements,
    this.challenges,
    required this.total,
    required this.completed,
    required this.progress,
    required this.timed,
    required this.items,
    this.updatedAt,
    this.offlinePending = false,
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
      id: _dailyInt(plan['id']),
      date: DateTime.tryParse(dateValue?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      title: plan['title']?.toString() ?? 'My Daily Plan',
      notes: plan['notes']?.toString(),
      achievements: plan['achievements']?.toString(),
      challenges: plan['challenges']?.toString(),
      total: _dailyInt(json['total'], rows.length),
      completed: _dailyInt(json['completed'], rows.where((e) => _dailyBool(e['is_completed'])).length),
      progress: _dailyInt(json['progress']),
      timed: _dailyInt(json['timed'], rows.where((e) => (e['start_time']?.toString().isNotEmpty ?? false)).length),
      items: rows.map(DailyPlanItem.fromJson).toList(),
      updatedAt: plan['updated_at'] != null ? DateTime.tryParse(plan['updated_at'].toString())?.toLocal() : null,
      offlinePending: plan['_offline_pending'] == true,
    );
  }
}

class DailyPlanHistoryItem {
  final int id;
  final DateTime date;
  final String title;
  final String? notes;
  final String? achievements;
  final String? challenges;
  final int total;
  final int completed;
  final int progress;

  const DailyPlanHistoryItem({
    required this.id,
    required this.date,
    required this.title,
    this.notes,
    this.achievements,
    this.challenges,
    required this.total,
    required this.completed,
    required this.progress,
  });

  factory DailyPlanHistoryItem.fromJson(Map<String, dynamic> json) => DailyPlanHistoryItem(
        id: _dailyInt(json['id']),
        date: DateTime.parse(json['plan_date'].toString()).toLocal(),
        title: json['title']?.toString() ?? 'My Daily Plan',
        notes: json['notes']?.toString(),
      achievements: json['achievements']?.toString(),
      challenges: json['challenges']?.toString(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        progress: _dailyInt(json['progress']),
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
