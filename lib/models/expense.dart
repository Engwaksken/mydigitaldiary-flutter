/// A single line item of an itemized expense (like a receipt with
/// several products) — matches app/Models/ExpenseItem.php. quantity
/// and unitPrice are strings while editing (TextField-friendly);
/// totalPrice is server-computed and read-only.
class ExpenseItem {
  final String description;
  final String quantity;
  final String unitPrice;
  final double? totalPrice;

  ExpenseItem({required this.description, required this.quantity, required this.unitPrice, this.totalPrice});

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
        description: json['description'] ?? '',
        quantity: json['quantity']?.toString() ?? '',
        unitPrice: json['unit_price']?.toString() ?? '',
        totalPrice: json['total_price'] != null ? double.tryParse(json['total_price'].toString()) : null,
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': double.tryParse(quantity) ?? 0,
        'unit_price': double.tryParse(unitPrice) ?? 0,
      };
}

/// Matches Api\ExpenseController's JSON shape.
class Expense {
  final int id;
  final String category;
  final double amount;
  final DateTime spentAt;
  final String? paymentMethod;
  final String? notes;
  final List<ExpenseItem> items;
  final DateTime? updatedAt;
  final bool offlinePending;

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.spentAt,
    required this.paymentMethod,
    required this.notes,
    this.items = const [],
    this.updatedAt,
    this.offlinePending = false,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as int,
      category: json['category'] as String,
      amount: double.parse(json['amount'].toString()),
      spentAt: DateTime.parse(json['spent_at'] as String).toLocal(),
      paymentMethod: json['payment_method'] as String?,
      notes: json['notes'] as String?,
      items: json['items'] != null ? (json['items'] as List).map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e))).toList() : const [],
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() : null,
      offlinePending: json['_offline_pending'] == true,
    );
  }

  /// [includeItems] is opt-in — omitting the `items` key entirely
  /// (rather than sending an empty array) matters on update(), since
  /// the server treats a genuinely-absent key as "don't touch
  /// existing items" versus an empty array meaning "clear them all."
  /// See Api\ExpenseController::update()'s $request->has('items')
  /// check. amount is always sent regardless — the server
  /// authoritatively recomputes it from items when any are present,
  /// so there's no need to conditionally omit it here.
  Map<String, dynamic> toJson({bool includeItems = false}) {
    return {
      'category': category,
      'amount': amount,
      'spent_at': spentAt.toIso8601String().split('T').first,
      'payment_method': paymentMethod,
      'notes': notes,
      if (includeItems) 'items': items.map((i) => i.toJson()).toList(),
    };
  }
}
