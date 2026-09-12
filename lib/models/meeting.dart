/// Matches Api\MeetingController's JSON shape (see the Laravel package's
/// app/Http/Controllers/Api/MeetingController.php).
class Meeting {
  final int id;
  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final String? location;
  final String? attendees;
  final String status;
  final String? notes;
  final String? recurrenceFrequency; // null, 'daily', 'weekly', 'monthly'
  final List<int> recurrenceDaysOfWeek; // ISO: 1=Mon...7=Sun, weekly only
  final DateTime? recurrenceEndsAt;
  final int? recurrenceParentId;

  Meeting({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.location,
    required this.attendees,
    required this.status,
    required this.notes,
    this.recurrenceFrequency,
    this.recurrenceDaysOfWeek = const [],
    this.recurrenceEndsAt,
    this.recurrenceParentId,
  });

  bool get isRecurring =>
      recurrenceFrequency != null && recurrenceFrequency!.isNotEmpty;

  /// A generated instance (not the original recurring series' own
  /// definition) — these shouldn't show their own recurrence
  /// controls when edited, since only the parent carries the rule.
  bool get isGeneratedInstance => recurrenceParentId != null;

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] as int,
      title: json['title'] as String,
      startAt: DateTime.parse(json['start_at'] as String).toLocal(),
      endAt: json['end_at'] != null
          ? DateTime.parse(json['end_at'] as String).toLocal()
          : null,
      location: json['location'] as String?,
      attendees: json['attendees'] as String?,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      recurrenceFrequency: json['recurrence_frequency'] as String?,
      recurrenceDaysOfWeek: json['recurrence_days_of_week'] != null
          ? List<int>.from(json['recurrence_days_of_week'])
          : const [],
      recurrenceEndsAt: json['recurrence_ends_at'] != null
          ? DateTime.tryParse(json['recurrence_ends_at'].toString())
          : null,
      recurrenceParentId: json['recurrence_parent_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
      'location': location,
      'attendees': attendees,
      'status': status,
      'notes': notes,
      'recurrence_frequency': recurrenceFrequency,
      if (recurrenceFrequency != null)
        'recurrence_days_of_week': recurrenceDaysOfWeek,
      if (recurrenceFrequency != null)
        'recurrence_ends_at':
            recurrenceEndsAt?.toIso8601String().split('T').first,
    };
  }
}
