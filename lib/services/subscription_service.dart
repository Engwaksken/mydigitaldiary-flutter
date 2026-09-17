import 'dart:async';

import '../models/subscription.dart';
import 'api_client.dart';

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
    final rawId = json['transaction_id'] ?? json['transactionId'] ?? json['id'];

    final parsedId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '');

    final redirect =
        json['redirect_url'] ??
        json['card_redirect_url'] ??
        json['cardRedirectUrl'] ??
        json['checkout_url'] ??
        json['checkoutUrl'];

    final explicitSuccess = json['success'];

    return IoTecPaymentStart(
      // Some successful initiation responses only return transaction/status.
      success: explicitSuccess == null
          ? parsedId != null
          : explicitSuccess == true,
      transactionId: parsedId,
      paymentChannel: (json['payment_channel'] ?? json['paymentChannel'] ?? '')
          .toString()
          .toLowerCase(),
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      redirectUrl: redirect?.toString(),
      message:
          (json['message'] ??
                  json['status_message'] ??
                  json['statusMessage'] ??
                  '')
              .toString(),
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

  bool get isSuccessful =>
      (status == 'success' ||
          status == 'successful' ||
          status == 'completed' ||
          status == 'paid' ||
          paid) &&
      (activated || paid);

  bool get isFinalFailure =>
      status == 'failed' ||
      status == 'cancelled' ||
      status == 'canceled' ||
      status == 'rejected';

  bool get isPending => !isSuccessful && !isFinalFailure;

  factory IoTecPaymentStatus.fromJson(Map<String, dynamic> json) {
    final transaction = Map<String, dynamic>.from(
      (json['transaction'] as Map?) ?? json,
    );
    final subscription = Map<String, dynamic>.from(
      (json['subscription'] as Map?) ?? const {},
    );

    DateTime? parseDate(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '');
    }

    return IoTecPaymentStatus(
      success: json['success'] == true,
      transactionId: parseInt(transaction['id']) ?? 0,
      status: (transaction['status'] ?? 'pending').toString().toLowerCase(),
      statusMessage: transaction['status_message']?.toString(),
      paid: transaction['paid'] == true,
      activated: transaction['activated'] == true,
      subscriptionStatus: (subscription['status'] ?? '')
          .toString()
          .toLowerCase(),
      subscriptionPlanId: parseInt(subscription['plan_id']),
      subscriptionStartedAt: parseDate(subscription['started_at']),
      subscriptionExpiresAt: parseDate(subscription['expires_at']),
      trialEndsAt: parseDate(subscription['trial_ends_at']),
    );
  }
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
          .map((value) => value.toString().toLowerCase())
          .toList(growable: false),
      currency: (gateway['currency'] ?? 'UGX').toString(),
    );
  }
}

class SubscriptionService {
  final _api = ApiClient.instance;

  Map<String, dynamic> _parseStatusPayload(dynamic response) {
    final root = Map<String, dynamic>.from(response);
    final dynamic payload = root['data'] is Map ? root['data'] : root;

    if (payload is! Map) {
      throw ApiException(
        500,
        (root['message'] ?? 'Invalid subscription status response.').toString(),
      );
    }

    return Map<String, dynamic>.from(payload);
  }

  /// [cacheFirst] serves the last successful response instantly and refreshes
  /// in the background, calling [onRefresh] with the fresh value when it
  /// arrives — used by screens that would otherwise wait on every open.
  Future<Map<String, dynamic>> status({
    bool cacheFirst = false,
    void Function(Map<String, dynamic> data)? onRefresh,
  }) async {
    if (cacheFirst) {
      final raw = await _api.getFast(
        'subscription/status',
        onRefresh: (json) => onRefresh?.call(_parseStatusPayload(json)),
      );
      return _parseStatusPayload(raw);
    }
    final response = await _api.get('subscription/status', cacheable: true);
    return _parseStatusPayload(response);
  }

  Future<List<SubscriptionPlanInfo>> plans({
    bool cacheFirst = false,
    void Function(List<SubscriptionPlanInfo> data)? onRefresh,
  }) async {
    List<SubscriptionPlanInfo> parse(dynamic response) {
      final rows = (response['data'] as List).cast<Map<String, dynamic>>();
      return rows.map(SubscriptionPlanInfo.fromJson).toList();
    }

    if (cacheFirst) {
      final raw = await _api.getFast(
        'subscription/plans',
        onRefresh: (json) => onRefresh?.call(parse(json)),
      );
      return parse(raw);
    }
    final response = await _api.get('subscription/plans', cacheable: true);
    return parse(response);
  }

  Future<List<PaymentGatewayInfo>> gateways({
    bool cacheFirst = false,
    void Function(List<PaymentGatewayInfo> data)? onRefresh,
  }) async {
    List<PaymentGatewayInfo> parse(dynamic response) {
      final rows = (response['data'] as List).cast<Map<String, dynamic>>();
      return rows.map(PaymentGatewayInfo.fromJson).toList();
    }

    if (cacheFirst) {
      final raw = await _api.getFast(
        'subscription/gateways',
        onRefresh: (json) => onRefresh?.call(parse(json)),
      );
      return parse(raw);
    }
    final response = await _api.get('subscription/gateways', cacheable: true);
    return parse(response);
  }

  Future<PaymentPage> payments({
    int page = 1,
    int perPage = 10,
    bool cacheFirst = false,
    void Function(PaymentPage data)? onRefresh,
  }) async {
    final path = 'subscription/payments?page=$page&per_page=$perPage';
    PaymentPage parse(dynamic json) => PaymentPage.fromJson(json);

    if (cacheFirst) {
      final raw = await _api.getFast(
        path,
        onRefresh: (json) => onRefresh?.call(parse(json)),
      );
      return parse(raw);
    }
    final response = await _api.get(path, cacheable: true);
    return parse(response);
  }

  // ---------------------------------------------------------------------------
  // ioTec subscription payments
  // ---------------------------------------------------------------------------

  Future<IoTecGatewayOptions> ioTecOptions() async {
    final response = await _api.get(
      'subscription/iotec/options',
      cacheable: false,
    );

    return IoTecGatewayOptions.fromJson(Map<String, dynamic>.from(response));
  }

  Future<IoTecPaymentStart> payWithIoTecMobileMoney(
    int planId,
    String phoneNumber,
  ) async {
    final response = await _api.post('subscription/pay/iotec', {
      'subscription_plan_id': planId,
      'payment_channel': 'mobile_money',
      'phone': phoneNumber.trim(),
    });

    return IoTecPaymentStart.fromJson(Map<String, dynamic>.from(response));
  }

  Future<IoTecPaymentStart> payWithIoTecCard(
    int planId, {
    String cardBrand = 'visa',
  }) async {
    final response = await _api.post('subscription/pay/iotec', {
      'subscription_plan_id': planId,
      'payment_channel': 'card',
      'card_brand': cardBrand,
    });

    return IoTecPaymentStart.fromJson(Map<String, dynamic>.from(response));
  }

  Future<IoTecPaymentStatus> ioTecPaymentStatus(int transactionId) async {
    final response = await _api.get(
      'subscription/pay/iotec/$transactionId/status',
      cacheable: false,
    );

    return IoTecPaymentStatus.fromJson(Map<String, dynamic>.from(response));
  }

  Future<IoTecPaymentStatus> waitForIoTecPayment(
    int transactionId, {
    Duration pollEvery = const Duration(seconds: 4),
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    var current = await ioTecPaymentStatus(transactionId);

    while (current.isPending && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollEvery);
      current = await ioTecPaymentStatus(transactionId);
    }

    return current;
  }

  // ---------------------------------------------------------------------------
  // Existing pending/manual billing flows
  // ---------------------------------------------------------------------------

  Future<String> retryPendingMobileMoney(
    int paymentId,
    String phoneNumber,
    String network,
  ) async {
    final response = await _api.post(
      'subscription/payments/$paymentId/mobile-money',
      {'phone_number': phoneNumber, 'network': network},
    );

    return response['message'] as String? ?? 'Payment prompt sent.';
  }

  Future<String> submitPendingBankPayment(
    int paymentId,
    int paymentGatewayId,
    String reference,
  ) async {
    final response = await _api.post('subscription/payments/$paymentId/bank', {
      'payment_gateway_id': paymentGatewayId,
      'reference': reference,
    });

    return response['message'] as String? ?? 'Bank payment submitted.';
  }

  Future<String> submitManualPayment(
    int planId,
    int paymentGatewayId,
    String reference,
  ) async {
    final response = await _api.post('subscription/pay/manual', {
      'plan_id': planId,
      'payment_gateway_id': paymentGatewayId,
      'reference': reference,
    });

    return response['message'] as String? ??
        'Payment submitted for verification.';
  }

  // ---------------------------------------------------------------------------
  // Backward-compatible wrappers
  // ---------------------------------------------------------------------------
  //
  // These keep older callers compiling while routing new self-serve
  // subscription payments through ioTec.
  //

  Future<String> payWithCard(int planId) async {
    final start = await payWithIoTecCard(planId);

    if (!start.success) {
      throw ApiException(
        422,
        start.message.isEmpty
            ? 'Could not start the card payment.'
            : start.message,
      );
    }

    final url = start.redirectUrl;
    if (url == null || url.trim().isEmpty) {
      throw ApiException(
        422,
        'ioTec did not return a secure card checkout URL.',
      );
    }

    return url;
  }

  Future<String> payWithMobileMoney(
    int planId,
    String phoneNumber,
    String network,
  ) async {
    // ioTec determines the network from the phone number/payment request,
    // so the legacy `network` argument is intentionally retained only for
    // compatibility with existing screen code.
    final start = await payWithIoTecMobileMoney(planId, phoneNumber);

    if (!start.success) {
      throw ApiException(
        422,
        start.message.isEmpty
            ? 'Could not start the Mobile Money payment.'
            : start.message,
      );
    }

    return start.message.isEmpty
        ? 'Payment prompt sent. Approve it on your phone.'
        : start.message;
  }
}
