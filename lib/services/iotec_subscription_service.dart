import 'dart:async';

/// Thin adapter so this update does not assume a particular ApiClient method
/// signature. Connect this to your existing authenticated ApiClient once.
abstract class IoTecApiTransport {
  Future<Map<String, dynamic>> getJson(String path);
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  });
}

class IoTecGatewayOptions {
  final bool enabled;
  final bool supportsMobileMoney;
  final bool supportsCard;
  final List<String> cardBrands;
  final String currency;

  const IoTecGatewayOptions({
    required this.enabled,
    required this.supportsMobileMoney,
    required this.supportsCard,
    required this.cardBrands,
    required this.currency,
  });

  factory IoTecGatewayOptions.fromJson(Map<String, dynamic> json) {
    final gateway = Map<String, dynamic>.from(
      (json['gateway'] as Map?) ?? const {},
    );

    return IoTecGatewayOptions(
      enabled: gateway['enabled'] == true,
      supportsMobileMoney: gateway['supports_mobile_money'] == true,
      supportsCard: gateway['supports_card'] == true,
      cardBrands: ((gateway['card_brands'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      currency: (gateway['currency'] ?? 'UGX').toString(),
    );
  }
}

class IoTecPaymentStart {
  final bool success;
  final int? transactionId;
  final String paymentChannel;
  final String status;
  final String? redirectUrl;
  final String message;

  const IoTecPaymentStart({
    required this.success,
    required this.transactionId,
    required this.paymentChannel,
    required this.status,
    required this.redirectUrl,
    required this.message,
  });

  factory IoTecPaymentStart.fromJson(Map<String, dynamic> json) {
    final id = json['transaction_id'];

    return IoTecPaymentStart(
      success: json['success'] == true,
      transactionId: id is int ? id : int.tryParse(id?.toString() ?? ''),
      paymentChannel: (json['payment_channel'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      redirectUrl: json['redirect_url']?.toString(),
      message: (json['message'] ?? '').toString(),
    );
  }
}

class IoTecPaymentStatus {
  final bool success;
  final int transactionId;
  final String status;
  final String? statusMessage;
  final bool paid;
  final bool activated;
  final String subscriptionStatus;
  final int? subscriptionPlanId;
  final DateTime? subscriptionStartedAt;
  final DateTime? subscriptionExpiresAt;
  final DateTime? trialEndsAt;

  const IoTecPaymentStatus({
    required this.success,
    required this.transactionId,
    required this.status,
    required this.statusMessage,
    required this.paid,
    required this.activated,
    required this.subscriptionStatus,
    required this.subscriptionPlanId,
    required this.subscriptionStartedAt,
    required this.subscriptionExpiresAt,
    required this.trialEndsAt,
  });

  bool get isSuccess => status == 'success' && activated;

  bool get isFinalFailure =>
      status == 'failed' ||
      status == 'cancelled' ||
      status == 'canceled' ||
      status == 'rejected';

  factory IoTecPaymentStatus.fromJson(Map<String, dynamic> json) {
    final transaction = Map<String, dynamic>.from(
      (json['transaction'] as Map?) ?? const {},
    );
    final subscription = Map<String, dynamic>.from(
      (json['subscription'] as Map?) ?? const {},
    );

    DateTime? parseDate(dynamic value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    final txId = transaction['id'];

    return IoTecPaymentStatus(
      success: json['success'] == true,
      transactionId:
          txId is int ? txId : int.tryParse(txId?.toString() ?? '') ?? 0,
      status: (transaction['status'] ?? 'pending').toString().toLowerCase(),
      statusMessage: transaction['status_message']?.toString(),
      paid: transaction['paid'] == true,
      activated: transaction['activated'] == true,
      subscriptionStatus:
          (subscription['status'] ?? '').toString().toLowerCase(),
      subscriptionPlanId: subscription['plan_id'] is int
          ? subscription['plan_id'] as int
          : int.tryParse(subscription['plan_id']?.toString() ?? ''),
      subscriptionStartedAt: parseDate(subscription['started_at']),
      subscriptionExpiresAt: parseDate(subscription['expires_at']),
      trialEndsAt: parseDate(subscription['trial_ends_at']),
    );
  }
}

class IoTecSubscriptionService {
  final IoTecApiTransport api;

  const IoTecSubscriptionService(this.api);

  Future<IoTecGatewayOptions> options() async {
    final json = await api.getJson('subscription/iotec/options');
    return IoTecGatewayOptions.fromJson(json);
  }

  Future<IoTecPaymentStart> startMobileMoney({
    required int planId,
    required String phone,
  }) async {
    final json = await api.postJson(
      'subscription/pay/iotec',
      body: {
        'subscription_plan_id': planId,
        'payment_channel': 'mobile_money',
        'phone': phone.trim(),
      },
    );

    return IoTecPaymentStart.fromJson(json);
  }

  Future<IoTecPaymentStart> startCard({
    required int planId,
    String cardBrand = 'visa',
  }) async {
    final json = await api.postJson(
      'subscription/pay/iotec',
      body: {
        'subscription_plan_id': planId,
        'payment_channel': 'card',
        'card_brand': cardBrand,
      },
    );

    return IoTecPaymentStart.fromJson(json);
  }

  Future<IoTecPaymentStatus> status(int transactionId) async {
    final json = await api.getJson(
      'subscription/pay/iotec/$transactionId/status',
    );

    return IoTecPaymentStatus.fromJson(json);
  }

  /// Polls while the transaction is awaiting gateway completion.
  ///
  /// Webhook activation still runs independently on Laravel, so this is only
  /// for fast mobile UI feedback and refreshing the subscription state.
  Future<IoTecPaymentStatus> waitForFinalStatus(
    int transactionId, {
    Duration interval = const Duration(seconds: 4),
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final endAt = DateTime.now().add(timeout);
    IoTecPaymentStatus last = await status(transactionId);

    while (!last.isSuccess &&
        !last.isFinalFailure &&
        DateTime.now().isBefore(endAt)) {
      await Future<void>.delayed(interval);
      last = await status(transactionId);
    }

    return last;
  }
}
