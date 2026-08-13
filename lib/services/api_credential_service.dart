import 'api_client.dart';

class ApiCredential {
  final int id;
  final String label;
  final String provider;
  final bool isActive;

  ApiCredential({required this.id, required this.label, required this.provider, required this.isActive});

  factory ApiCredential.fromJson(Map<String, dynamic> json) => ApiCredential(
        id: json['id'],
        label: json['label'] ?? '',
        provider: json['provider'] ?? '',
        isActive: json['is_active'] ?? false,
      );
}

class AiProviderOption {
  final String key;
  final String name;

  AiProviderOption({required this.key, required this.name});

  factory AiProviderOption.fromJson(Map<String, dynamic> json) => AiProviderOption(key: json['key'] ?? '', name: json['name'] ?? '');
}

class ApiCredentialsOverview {
  final List<ApiCredential> credentials;
  final bool hasOwnActiveKey;
  final bool hasSharedKeyConfigured;
  final int sharedUsedThisMonth;
  final int sharedLimitPerMonth;
  final List<AiProviderOption> providers;

  ApiCredentialsOverview({
    required this.credentials,
    required this.hasOwnActiveKey,
    required this.hasSharedKeyConfigured,
    required this.sharedUsedThisMonth,
    required this.sharedLimitPerMonth,
    required this.providers,
  });

  factory ApiCredentialsOverview.fromJson(Map<String, dynamic> json) => ApiCredentialsOverview(
        credentials: (json['data'] as List).map((e) => ApiCredential.fromJson(e)).toList(),
        hasOwnActiveKey: json['has_own_active_key'] ?? false,
        hasSharedKeyConfigured: json['has_shared_key_configured'] ?? false,
        sharedUsedThisMonth: json['shared_used_this_month'] ?? 0,
        sharedLimitPerMonth: json['shared_limit_per_month'] ?? 0,
        providers: (json['providers'] as List).map((e) => AiProviderOption.fromJson(e)).toList(),
      );
}

/// Mobile equivalent of the web app's /api-credentials — lets a user
/// add their own AI provider key(s) so AI Plan generation uses those
/// (unlimited, their own cost) instead of the site's shared, admin-
/// supplied default key (free, but capped at a monthly limit per
/// user — see AiPlannerService::generate() on the Laravel side for
/// the exact fallback logic both web and mobile share).
class ApiCredentialService {
  final _api = ApiClient.instance;

  Future<ApiCredentialsOverview> overview() async {
    final response = await _api.get('api-credentials');
    return ApiCredentialsOverview.fromJson(response);
  }

  Future<void> add({required String label, required String provider, required String apiKey}) =>
      _api.post('api-credentials', {'label': label, 'provider': provider, 'api_key': apiKey});

  Future<void> activate(int id) => _api.post('api-credentials/$id/activate', {});

  Future<void> delete(int id) => _api.delete('api-credentials/$id');
}
