class BudgetImportItem {
  String category;
  String description;
  double plannedAmount;
  String period;
  String? monthYear;
  String? notes;
  double confidence;

  BudgetImportItem({
    required this.category,
    required this.description,
    required this.plannedAmount,
    this.period = 'monthly',
    this.monthYear,
    this.notes,
    this.confidence = 0,
  });

  factory BudgetImportItem.fromJson(Map<String, dynamic> json) {
    final period = json['period']?.toString();

    return BudgetImportItem(
      category:
          json['category']?.toString().trim().isNotEmpty == true
              ? json['category'].toString()
              : 'General',
      description: json['description']?.toString() ?? '',
      plannedAmount:
          _number(json['planned_amount'] ?? json['amount']),
      period: <String>[
        'weekly',
        'monthly',
        'annually',
      ].contains(period)
          ? period!
          : 'monthly',
      monthYear:
          json['month_year']?.toString() ?? json['date']?.toString(),
      notes: json['notes']?.toString(),
      confidence: _number(json['confidence']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'category': category,
      'description': description,
      'planned_amount': plannedAmount,
      'period': period,
      'month_year': monthYear,
      'notes': notes,
    };
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class BudgetImportDraft {
  String title;
  String currency;
  String? startDate;
  String? endDate;
  String? notes;
  double confidence;
  String? source;
  String? filename;
  List<BudgetImportItem> items;

  BudgetImportDraft({
    required this.title,
    required this.currency,
    this.startDate,
    this.endDate,
    this.notes,
    required this.confidence,
    this.source,
    this.filename,
    required this.items,
  });

  factory BudgetImportDraft.fromJson(Map<String, dynamic> json) {
    return BudgetImportDraft(
      title: json['title']?.toString() ?? 'Imported Budget',
      currency: json['currency']?.toString() ?? 'UGX',
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      notes: json['notes']?.toString(),
      confidence: BudgetImportItem._number(json['confidence']),
      source: json['source']?.toString(),
      filename: json['filename']?.toString(),
      items: (json['items'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => BudgetImportItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}
