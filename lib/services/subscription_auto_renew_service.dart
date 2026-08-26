import 'api_client.dart';

class SubscriptionAutoRenewInfo {
  final bool available;
  final bool enabled;
  final String? phoneNumber;
  final String network;
  final String? nextRenewalDate;
  final int? subscriptionPlanId;
  final String? subscriptionPlan;
  final String? gatewayName;
  final bool supportsMtn;
  final bool supportsAirtel;
  final String? message;

  const SubscriptionAutoRenewInfo({
    required this.available,
    required this.enabled,
    required this.phoneNumber,
    required this.network,
    required this.nextRenewalDate,
    required this.subscriptionPlanId,
    required this.subscriptionPlan,
    required this.gatewayName,
    required this.supportsMtn,
    required this.supportsAirtel,
    required this.message,
  });

  factory SubscriptionAutoRenewInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = Map<String, dynamic>.from(
      (json['data'] as Map?) ?? const {},
    );

    final gateway = data['gateway'] is Map
        ? Map<String, dynamic>.from(
            data['gateway'] as Map,
          )
        : <String, dynamic>{};

    int? parseInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '');
    }

    return SubscriptionAutoRenewInfo(
      available: data['available'] == true,
      enabled: data['enabled'] == true,
      phoneNumber: data['phone_number']?.toString(),
      network: (data['network'] ?? 'mtn')
          .toString()
          .toLowerCase(),
      nextRenewalDate:
          data['next_renewal_date']?.toString(),
      subscriptionPlanId:
          parseInt(data['subscription_plan_id']),
      subscriptionPlan:
          data['subscription_plan']?.toString(),
      gatewayName: gateway['name']?.toString(),
      supportsMtn:
          gateway['supports_mtn'] == true,
      supportsAirtel:
          gateway['supports_airtel'] == true,
      message: data['message']?.toString(),
    );
  }
}

class SubscriptionAutoRenewService {
  final ApiClient _api = ApiClient.instance;

  Future<SubscriptionAutoRenewInfo> getSettings() async {
    final response = await _api.get(
      'subscription/auto-renew',
      cacheable: false,
    );

    return SubscriptionAutoRenewInfo.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<String> enable({
    required String phoneNumber,
    required String network,
  }) async {
    final response = await _api.post(
      'subscription/auto-renew',
      {
        'enabled': true,
        'phone_number': phoneNumber.trim(),
        'network': network,
      },
    );

    return response['message']?.toString()
        ?? 'Auto renewal enabled.';
  }

  Future<String> disable() async {
    final response = await _api.post(
      'subscription/auto-renew',
      {
        'enabled': false,
      },
    );

    return response['message']?.toString()
        ?? 'Auto renewal disabled.';
  }
}
