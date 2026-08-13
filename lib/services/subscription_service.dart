import '../models/subscription.dart';
import 'api_client.dart';

class SubscriptionService {
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> status() async {
    final response = await _api.get('subscription/status');
    return Map<String, dynamic>.from(response['data']);
  }

  Future<List<SubscriptionPlanInfo>> plans() async {
    final response = await _api.get('subscription/plans');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(SubscriptionPlanInfo.fromJson).toList();
  }

  Future<List<PaymentGatewayInfo>> gateways() async {
    final response = await _api.get('subscription/gateways');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(PaymentGatewayInfo.fromJson).toList();
  }

  Future<PaymentPage> payments({int page = 1, int perPage = 10}) async {
    final response = await _api.get('subscription/payments?page=$page&per_page=$perPage');
    return PaymentPage.fromJson(response);
  }

  Future<String> retryPendingMobileMoney(
    int paymentId,
    String phoneNumber,
    String network,
  ) async {
    final response = await _api.post(
      'subscription/payments/$paymentId/mobile-money',
      {
        'phone_number': phoneNumber,
        'network': network,
      },
    );
    return response['message'] as String? ?? 'Payment prompt sent.';
  }

  Future<String> submitPendingBankPayment(
    int paymentId,
    int paymentGatewayId,
    String reference,
  ) async {
    final response = await _api.post(
      'subscription/payments/$paymentId/bank',
      {
        'payment_gateway_id': paymentGatewayId,
        'reference': reference,
      },
    );
    return response['message'] as String? ?? 'Bank payment submitted.';
  }

  /// Returns the Stripe checkout URL to open in an external browser —
  /// there's no way to safely embed a card entry form directly in this
  /// app, so completing payment happens in the device's own browser,
  /// same as how a mobile web visitor would experience it.
  Future<String> payWithCard(int planId) async {
    final response = await _api.post('subscription/pay/card', {'plan_id': planId});
    return response['data']['checkout_url'] as String;
  }

  Future<String> payWithMobileMoney(int planId, String phoneNumber, String network) async {
    final response = await _api.post('subscription/pay/mobile-money', {
      'plan_id': planId,
      'phone_number': phoneNumber,
      'network': network,
    });
    return response['message'] as String;
  }

  Future<String> submitManualPayment(int planId, int paymentGatewayId, String reference) async {
    final response = await _api.post('subscription/pay/manual', {
      'plan_id': planId,
      'payment_gateway_id': paymentGatewayId,
      'reference': reference,
    });
    return response['message'] as String;
  }
}
