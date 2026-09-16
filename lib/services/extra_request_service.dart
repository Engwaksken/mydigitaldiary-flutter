import 'dart:async';

import '../models/extra_request.dart';
import 'api_client.dart';

class ExtraPayResult {
  final ExtraRequest request;
  final ExtraRequestTransaction? transaction;
  final String? cardRedirectUrl;

  const ExtraPayResult({
    required this.request,
    this.transaction,
    this.cardRedirectUrl,
  });
}

class ExtraRequestService {
  final _api = ApiClient.instance;

  Future<List<ExtraRequest>> list() async {
    final response = await _api.get('extra-requests');
    final rows = (response is Map ? response['data'] : response);
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((e) => ExtraRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ExtraRequest> create({
    required int quotaAmount,
    required double amount,
    String? currency,
    String? description,
  }) async {
    final response = await _api.post('extra-requests', {
      'quota_amount': quotaAmount,
      'amount': amount,
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });

    final payload = response is Map ? response['data'] : response;
    final json = Map<String, dynamic>.from((payload is Map) ? payload : {});
    return ExtraRequest.fromJson(json);
  }

  Future<ExtraRequest> show(int id) async {
    final response = await _api.get('extra-requests/$id');
    final payload = response is Map ? response['data'] : response;
    final json = Map<String, dynamic>.from((payload is Map) ? payload : {});
    return ExtraRequest.fromJson(json);
  }

  Future<ExtraPayResult> pay(
    int id, {
    required String paymentChannel,
    required String payer,
  }) async {
    final response = await _api.post('extra-requests/$id/pay', {
      'payment_channel': paymentChannel,
      'payer': payer.trim(),
    });

    final data = response is Map ? response['data'] : response;
    final map = Map<String, dynamic>.from((data is Map) ? data : {});

    final requestJson = map['request'];
    final transactionJson = map['transaction'];

    return ExtraPayResult(
      request: requestJson is Map
          ? ExtraRequest.fromJson(Map<String, dynamic>.from(requestJson))
          : throw ApiException(422, 'Could not read the payment response.'),
      transaction: transactionJson is Map
          ? ExtraRequestTransaction.fromJson(
              Map<String, dynamic>.from(transactionJson))
          : null,
      cardRedirectUrl: (map['card_redirect_url'] ??
              map['redirect_url'] ??
              map['checkout_url'])
          ?.toString(),
    );
  }

  /// Polls the request until the backend confirms payment and applies the
  /// extra quota. The subscription status endpoint is subscription-specific,
  /// so for extra requests we poll the request itself until it moves out of
  /// 'pending'.
  Future<ExtraRequest> waitForSettled(
    int id, {
    Duration interval = const Duration(seconds: 4),
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);

    var current = await show(id);
    while (current.isPending && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      current = await show(id);
    }

    return current;
  }
}