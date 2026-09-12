class TodayInsight {
  final String category;
  final String type;
  final String title;
  final String message;
  final String action;
  final String destination;
  final String tone;
  final String generatedBy;
  final String? provider;
  final String? providerName;
  final String? model;
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
    this.provider,
    this.providerName,
    this.model,
    this.generatedAt,
    this.refreshAfter,
  });

  bool get isAiGenerated => generatedBy == 'admin_ai';

  factory TodayInsight.fromJson(Map<String, dynamic> json) {
    return TodayInsight(
      category: json['category']?.toString() ?? 'Today',
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      action: json['action']?.toString() ?? 'Open planner',
      destination: json['destination']?.toString() ?? 'daily-planner',
      tone: json['tone']?.toString() ?? 'teal',
      generatedBy: json['generated_by']?.toString() ?? 'server',
      provider: json['provider']?.toString(),
      providerName: json['provider_name']?.toString(),
      model: json['model']?.toString(),
      generatedAt: DateTime.tryParse(
        json['generated_at']?.toString() ?? '',
      )?.toLocal(),
      refreshAfter: DateTime.tryParse(
        json['refresh_after']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}
