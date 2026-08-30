class DailyPlannerSnapshot {
  final DailyPlanInfo plan;
  final List<DailyPlannerItem> items;
  final int total;
  final int completed;
  final int pending;
  final int timed;
  final int progress;

  const DailyPlannerSnapshot({
    required this.plan,
    required this.items,
    required this.total,
    required this.completed,
    required this.pending,
    required this.timed,
    required this.progress,
  });

  /// Backward-compatible date expected by EngagementService.
  ///
  /// The recurrence-aware API stores the selected day on plan.planDate.
  DateTime get date {
    final parsed = DateTime.tryParse(plan.planDate);

    if (parsed != null) {
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
      );
    }

    return DateTime(1970, 1, 1);
  }

  factory DailyPlannerSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['plan'];
    final rawItems = json['items'];

    return DailyPlannerSnapshot(
      plan: DailyPlanInfo.fromJson(
        rawPlan is Map
            ? Map<String, dynamic>.from(rawPlan)
            : <String, dynamic>{},
      ),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => DailyPlannerItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const <DailyPlannerItem>[],
      total: _asInt(json['total']),
      completed: _asInt(json['completed']),
      pending: _asInt(json['pending']),
      timed: _asInt(json['timed']),
      progress: _asInt(json['progress']),
    );
  }
}

class DailyPlanInfo {
  final int id;
  final String? title;
  final String planDate;
  final String? notes;
  final String? achievements;
  final String? challenges;

  const DailyPlanInfo({
    required this.id,
    required this.title,
    required this.planDate,
    this.notes,
    this.achievements,
    this.challenges,
  });

  factory DailyPlanInfo.fromJson(Map<String, dynamic> json) {
    return DailyPlanInfo(
      id: _asInt(json['id']),
      title: _nullableString(json['title']),
      planDate: _dateOnly(json['plan_date']),
      notes: _nullableString(json['notes']),
      achievements: _nullableString(json['achievements']),
      challenges: _nullableString(json['challenges']),
    );
  }
}

class DailyPlannerItem {
  final int id;
  final int dailyPlanId;
  final int? personalGoalId;
  final String? personalGoalTitle;
  final String title;
  final String? description;
  final String priority;
  final String? startTime;
  final String? endTime;
  final bool isCompleted;
  final String? completedAt;

  final String repeatType;
  final List<String> repeatDays;
  final int repeatInterval;
  final String? repeatStartsOn;
  final String? repeatEndsOn;
  final String? recurrenceGroupId;
  final String occurrenceDate;
  final String repeatLabel;

  const DailyPlannerItem({
    required this.id,
    required this.dailyPlanId,
    this.personalGoalId,
    this.personalGoalTitle,
    required this.title,
    this.description,
    required this.priority,
    this.startTime,
    this.endTime,
    required this.isCompleted,
    this.completedAt,
    required this.repeatType,
    required this.repeatDays,
    required this.repeatInterval,
    this.repeatStartsOn,
    this.repeatEndsOn,
    this.recurrenceGroupId,
    required this.occurrenceDate,
    required this.repeatLabel,
  });

  bool get isRecurring => repeatType != 'once';

  factory DailyPlannerItem.fromJson(Map<String, dynamic> json) {
    final rawGoal = json['personal_goal'] ?? json['personalGoal'];
    String? goalTitle;

    if (rawGoal is Map) {
      goalTitle = _nullableString(rawGoal['title']);
    }

    final rawDays = json['repeat_days'];
    final days = <String>[];

    if (rawDays is List) {
      for (final day in rawDays) {
        final value = day?.toString().trim().toLowerCase();
        if (value != null && value.isNotEmpty) {
          days.add(value);
        }
      }
    }

    final repeatType = _nullableString(json['repeat_type']) ?? 'once';
    final occurrenceDate = _dateOnly(
      json['occurrence_date'] ?? json['plan_date'],
    );

    return DailyPlannerItem(
      id: _asInt(json['id']),
      dailyPlanId: _asInt(json['daily_plan_id']),
      personalGoalId: _asNullableInt(json['personal_goal_id']),
      personalGoalTitle: goalTitle,
      title: _nullableString(json['title']) ?? 'Untitled task',
      description: _nullableString(json['description']),
      priority: _nullableString(json['priority']) ?? 'medium',
      startTime: _timeOnly(json['start_time']),
      endTime: _timeOnly(json['end_time']),
      isCompleted: _asBool(json['is_completed']),
      completedAt: _nullableString(json['completed_at']),
      repeatType: repeatType,
      repeatDays: List<String>.unmodifiable(days),
      repeatInterval: _asInt(json['repeat_interval'], fallback: 1),
      repeatStartsOn: _nullableDate(json['repeat_starts_on']),
      repeatEndsOn: _nullableDate(json['repeat_ends_on']),
      recurrenceGroupId: _nullableString(json['recurrence_group_id']),
      occurrenceDate: occurrenceDate,
      repeatLabel: _nullableString(json['repeat_label']) ??
          _fallbackRepeatLabel(repeatType, days),
    );
  }
}

class PersonalGoalOption {
  final int id;
  final String title;

  const PersonalGoalOption({
    required this.id,
    required this.title,
  });

  factory PersonalGoalOption.fromJson(Map<String, dynamic> json) {
    return PersonalGoalOption(
      id: _asInt(json['id']),
      title: _nullableString(json['title']) ?? 'Goal',
    );
  }
}

class DailyPlannerTaskDraft {
  final String planDate;
  final String title;
  final String? description;
  final int? personalGoalId;
  final String priority;
  final String? startTime;
  final String? endTime;
  final String repeatType;
  final List<String> repeatDays;
  final int repeatInterval;
  final String? repeatStartsOn;
  final String? repeatEndsOn;
  final String? occurrenceDate;
  final String? editScope;

  const DailyPlannerTaskDraft({
    required this.planDate,
    required this.title,
    this.description,
    this.personalGoalId,
    required this.priority,
    this.startTime,
    this.endTime,
    required this.repeatType,
    this.repeatDays = const <String>[],
    this.repeatInterval = 1,
    this.repeatStartsOn,
    this.repeatEndsOn,
    this.occurrenceDate,
    this.editScope,
  });

  Map<String, dynamic> toJson({
    required bool creating,
  }) {
    final json = <String, dynamic>{
      if (creating) 'plan_date': planDate,
      'title': title.trim(),
      'description': _blankToNull(description),
      'personal_goal_id': personalGoalId,
      'priority': priority,
      'start_time': _blankToNull(startTime),
      'end_time': _blankToNull(endTime),
      'repeat_type': repeatType,
      'repeat_days': repeatType == 'specific_days'
          ? repeatDays
          : <String>[],
      'repeat_interval': repeatInterval,
      'repeat_starts_on':
          repeatType == 'once' ? null : (repeatStartsOn ?? planDate),
      'repeat_ends_on':
          repeatType == 'once' ? null : _blankToNull(repeatEndsOn),
    };

    if (!creating) {
      json['plan_date'] = planDate;
      json['occurrence_date'] = occurrenceDate;
      json['edit_scope'] = editScope ?? 'series';
    }

    return json;
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  final parsed = _asInt(value, fallback: -1);
  return parsed < 0 ? null : parsed;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final text = value?.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes';
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _dateOnly(dynamic value) {
  final text = _nullableString(value) ?? '';
  return text.length >= 10 ? text.substring(0, 10) : text;
}

String? _nullableDate(dynamic value) {
  final valueText = _nullableString(value);
  if (valueText == null) return null;
  return _dateOnly(valueText);
}

String? _timeOnly(dynamic value) {
  final text = _nullableString(value);
  if (text == null) return null;
  return text.length >= 5 ? text.substring(0, 5) : text;
}

String? _blankToNull(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

String _fallbackRepeatLabel(
  String repeatType,
  List<String> days,
) {
  const shortDays = <String, String>{
    'monday': 'Mon',
    'tuesday': 'Tue',
    'wednesday': 'Wed',
    'thursday': 'Thu',
    'friday': 'Fri',
    'saturday': 'Sat',
    'sunday': 'Sun',
  };

  switch (repeatType) {
    case 'daily':
      return 'Every day';
    case 'weekly':
      return 'Every week';
    case 'monthly':
      return 'Every month';
    case 'specific_days':
      final values = days
          .map((day) => shortDays[day] ?? day)
          .toList();
      return values.isEmpty ? 'Specific days' : values.join(' • ');
    default:
      return 'Once';
  }
}
