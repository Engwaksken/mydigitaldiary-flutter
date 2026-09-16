class ExtraRequest {
  final int id;
  final int userId;
  final String requestType;
  final String? description;
  final String status;
  final double amount;
  final String currency;
  final int? iotecTransactionId;
  final int quotaAmount;
  final int quotaUsed;
  final DateTime? appliedAt;
  final DateTime? expiresAt;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final ExtraRequestTransaction? iotecTransaction;

  ExtraRequest({
    required this.id,
    required this.userId,
    required this.requestType,
    this.description,
    required this.status,
    required this.amount,
    required this.currency,
    this.iotecTransactionId,
    required this.quotaAmount,
    required this.quotaUsed,
    this.appliedAt,
    this.expiresAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.iotecTransaction,
  });

  factory ExtraRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    final transactionJson = json['iotec_transaction'];
    return ExtraRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      requestType: json['request_type'] ?? 'extra_recording_quota',
      description: json['description']?.toString(),
      status: json['status'] ?? 'pending',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] ?? '',
      iotecTransactionId: (json['iotec_transaction_id'] as num?)?.toInt(),
      quotaAmount: (json['quota_amount'] as num?)?.toInt() ?? 0,
      quotaUsed: (json['quota_used'] as num?)?.toInt() ?? 0,
      appliedAt: parseDate(json['applied_at']),
      expiresAt: parseDate(json['expires_at']),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      iotecTransaction: transactionJson is Map
          ? ExtraRequestTransaction.fromJson(
              Map<String, dynamic>.from(transactionJson))
          : null,
    );
  }

  bool get isApplied => status == 'applied';

  bool get isPending => status == 'pending';

  bool get isTerminalFailure =>
      status == 'failed' ||
      status == 'rejected' ||
      status == 'cancelled' ||
      status == 'canceled';

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  int get remainingQuota => (quotaAmount - quotaUsed).clamp(0, quotaAmount);

  String get formattedAmount =>
      '$currency ${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}';
}

class ExtraRequestTransaction {
  final int? id;
  final String status;
  final String? statusMessage;
  final String? paymentChannel;
  final String? payer;
  final String? cardRedirectUrl;
  final DateTime? paidAt;
  final String? createdAt;

  ExtraRequestTransaction({
    this.id,
    required this.status,
    this.statusMessage,
    this.paymentChannel,
    this.payer,
    this.cardRedirectUrl,
    this.paidAt,
    this.createdAt,
  });

  factory ExtraRequestTransaction.fromJson(Map<String, dynamic> json) {
    final text = json['paid_at']?.toString();
    final created = json['created_at']?.toString();
    return ExtraRequestTransaction(
      id: (json['id'] as num?)?.toInt(),
      status: json['status'] ?? 'pending',
      statusMessage: json['status_message']?.toString(),
      paymentChannel: json['payment_channel']?.toString(),
      payer: json['payer']?.toString(),
      cardRedirectUrl: json['card_redirect_url']?.toString(),
      paidAt: text == null ? null : DateTime.tryParse(text),
      createdAt: created,
    );
  }
}