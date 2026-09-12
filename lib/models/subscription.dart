class SubscriptionPlanInfo {
  final int id;
  final String name;
  final String category;
  final bool isLifetime;
  final int? durationMonths;
  final double price;
  final String currencyCode;
  final String currencySymbol;
  final String? savingsLabel;
  final String color;
  final String? badge;
  final bool isRecommended;
  final bool isBestValue;
  final int includedMembers;
  final double? pricePerMember;
  final double? additionalMemberPrice;

  SubscriptionPlanInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.isLifetime,
    this.durationMonths,
    required this.price,
    required this.currencyCode,
    required this.currencySymbol,
    this.savingsLabel,
    required this.color,
    this.badge,
    this.isRecommended = false,
    this.isBestValue = false,
    this.includedMembers = 1,
    this.pricePerMember,
    this.additionalMemberPrice,
  });

  factory SubscriptionPlanInfo.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlanInfo(
        id: json['id'],
        name: json['name'] ?? '',
        category: json['category'] ?? 'individual',
        isLifetime: json['is_lifetime'] ?? false,
        durationMonths: json['duration_months'],
        price: (json['price'] as num?)?.toDouble() ?? 0,
        currencyCode: json['currency_code'] ?? '',
        currencySymbol: json['currency_symbol'] ?? '',
        savingsLabel: json['savings_label'],
        color: json['color'] ?? '#475569',
        badge: json['badge'],
        isRecommended: json['is_recommended'] ?? false,
        isBestValue: json['is_best_value'] ?? false,
        includedMembers: json['included_members'] ?? 1,
        pricePerMember: (json['price_per_member'] as num?)?.toDouble(),
        additionalMemberPrice:
            (json['additional_member_price'] as num?)?.toDouble(),
      );

  bool get isIndividual => category == 'individual';

  String categoryLabel() => switch (category) {
        'family_team' => 'Family & Small Team',
        'organization' => 'Organization',
        _ => 'Individual',
      };

  String formattedPrice() =>
      '$currencySymbol ${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}';
}

class PaymentGatewayInfo {
  final int id;
  final String type;
  final String name;
  final bool collectsAutomatically;
  final bool supportsMtn;
  final bool supportsAirtel;
  final String? instructions;
  final String? bankName;
  final String? accountName;
  final String? accountNumber;
  final String? routingOrSwift;
  final String? providerName;
  final String? merchantNumber;

  PaymentGatewayInfo({
    required this.id,
    required this.type,
    required this.name,
    required this.collectsAutomatically,
    required this.supportsMtn,
    required this.supportsAirtel,
    this.instructions,
    this.bankName,
    this.accountName,
    this.accountNumber,
    this.routingOrSwift,
    this.providerName,
    this.merchantNumber,
  });

  bool get isCard => type.toLowerCase() == 'card';
  bool get isMobileMoney =>
      type.toLowerCase() == 'mobile_money' || collectsAutomatically;

  factory PaymentGatewayInfo.fromJson(Map<String, dynamic> json) =>
      PaymentGatewayInfo(
        id: json['id'],
        type: json['type'] ?? '',
        name: json['name'] ?? '',
        collectsAutomatically: json['collects_automatically'] ?? false,
        supportsMtn: json['supports_mtn'] ?? false,
        supportsAirtel: json['supports_airtel'] ?? false,
        instructions: json['instructions'],
        bankName: json['bank_name'],
        accountName: json['account_name'],
        accountNumber: json['account_number'],
        routingOrSwift: json['routing_or_swift'],
        providerName: json['provider_name'],
        merchantNumber: json['merchant_number'],
      );
}

class PaymentRecord {
  final int id;
  final int? planId;
  final String? plan;
  final int? gatewayId;
  final String? gatewayName;
  final String method;
  final double amount;
  final String currency;
  final String status;
  final String? contactPhone;
  final String? network;
  final String? receiptNumber;
  final bool hasInvoice;
  final String? invoiceStatus;
  final String createdAt;
  final String? receiptDownloadUrl;
  final String? invoiceDownloadUrl;

  PaymentRecord({
    required this.id,
    this.planId,
    this.plan,
    this.gatewayId,
    this.gatewayName,
    required this.method,
    required this.amount,
    required this.currency,
    required this.status,
    this.contactPhone,
    this.network,
    this.receiptNumber,
    required this.hasInvoice,
    this.invoiceStatus,
    required this.createdAt,
    this.receiptDownloadUrl,
    this.invoiceDownloadUrl,
  });

  bool get isPending => status.toLowerCase() == 'pending';

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['id'],
        planId: json['plan_id'],
        plan: json['plan'],
        gatewayId: json['gateway_id'],
        gatewayName: json['gateway_name'],
        method: json['method'] ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] ?? '',
        status: json['status'] ?? '',
        contactPhone: json['contact_phone'],
        network: json['network'],
        receiptNumber: json['receipt_number'],
        hasInvoice: json['has_invoice'] ?? false,
        invoiceStatus: json['invoice_status'],
        createdAt: json['created_at'] ?? '',
        receiptDownloadUrl: json['receipt_download_url'],
        invoiceDownloadUrl: json['invoice_download_url'],
      );
}

class PaymentPage {
  final List<PaymentRecord> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int? from;
  final int? to;

  const PaymentPage({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.from,
    this.to,
  });

  factory PaymentPage.fromJson(Map<String, dynamic> json) {
    final rows = (json['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PaymentRecord.fromJson)
        .toList();

    final meta = Map<String, dynamic>.from(json['meta'] ?? const {});

    return PaymentPage(
      data: rows,
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      perPage: (meta['per_page'] as num?)?.toInt() ?? 10,
      total: (meta['total'] as num?)?.toInt() ?? rows.length,
      from: (meta['from'] as num?)?.toInt(),
      to: (meta['to'] as num?)?.toInt(),
    );
  }
}
