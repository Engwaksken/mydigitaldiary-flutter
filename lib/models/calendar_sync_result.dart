class CalendarSyncResult {
  final int imported;
  final int updated;
  final int skipped;
  final int failed;
  final String from;
  final String to;
  final DateTime? syncedAt;
  final List<String> errors;

  const CalendarSyncResult({
    required this.imported,
    required this.updated,
    required this.skipped,
    required this.failed,
    required this.from,
    required this.to,
    required this.syncedAt,
    required this.errors,
  });

  factory CalendarSyncResult.fromJson(Map<String, dynamic> json) {
    return CalendarSyncResult(
      imported: (json['imported'] as num?)?.toInt() ?? 0,
      updated: (json['updated'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      syncedAt: DateTime.tryParse(json['synced_at']?.toString() ?? ''),
      errors: (json['errors'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}
