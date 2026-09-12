class AiPlan {
  final int id;
  final String content;
  final String? provider;
  final bool usedSharedKey;
  final DateTime createdAt;
  final String pdfUrl;

  AiPlan({
    required this.id,
    required this.content,
    this.provider,
    required this.usedSharedKey,
    required this.createdAt,
    required this.pdfUrl,
  });

  factory AiPlan.fromJson(Map<String, dynamic> json) => AiPlan(
        id: json['id'],
        content: json['content'] ?? '',
        provider: json['provider'],
        usedSharedKey: json['used_shared_key'] ?? false,
        createdAt: DateTime.tryParse(json['created_at'] ?? '')?.toLocal() ??
            DateTime.now(),
        pdfUrl: json['pdf_url'] ?? '',
      );
}
