class TodayInsight {
  final String category;
  final String type;
  final String title;
  final String message;
  final String action;
  final String destination;
  final String tone;
  final String generatedBy;
  final String? currencyCode;
  final String? currencySymbol;
  final DateTime? generatedAt;
  final DateTime? refreshAfter;

  const TodayInsight({
    required this.category,
    required this.type,
    required this.title,
    required this.message,
    required this.action,
    required this.destination,
    required this.tone,
    required this.generatedBy,
    this.currencyCode,
    this.currencySymbol,
    this.generatedAt,
    this.refreshAfter,
  });

  factory TodayInsight.fromJson(Map<String, dynamic> j) => TodayInsight(
    category: j['category']?.toString() ?? 'Today',
    type: j['type']?.toString() ?? 'general',
    title: j['title']?.toString() ?? '',
    message: j['message']?.toString() ?? '',
    action: j['action']?.toString() ?? 'Open planner',
    destination: j['destination']?.toString() ?? 'daily-planner',
    tone: j['tone']?.toString() ?? 'teal',
    generatedBy: j['generated_by']?.toString() ?? 'server',
    currencyCode: _currencyCode(j),
    currencySymbol: _currencySymbol(j),
    generatedAt: DateTime.tryParse(j['generated_at']?.toString() ?? ''),
    refreshAfter: DateTime.tryParse(j['refresh_after']?.toString() ?? ''),
  );


  static String? _currencyCode(Map<String, dynamic> json) {
    final raw = json['preferred_currency'] ??
        json['currency'] ??
        json['currency_code'];

    if (raw is Map) {
      final code = raw['code'] ??
          raw['currency_code'] ??
          raw['iso_code'];

      final value = code?.toString().trim().toUpperCase();
      return value == null || value.isEmpty ? null : value;
    }

    final value = raw?.toString().trim().toUpperCase();
    return value == null || value.isEmpty ? null : value;
  }

  static String? _currencySymbol(Map<String, dynamic> json) {
    final raw = json['preferred_currency'];

    if (raw is Map) {
      final value = raw['symbol']?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return null;
  }
}
