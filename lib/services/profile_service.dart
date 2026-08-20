import 'api_client.dart';

class ProfileService {
  final _api = ApiClient.instance;

  /// Load the signed-in user's avatar through the authenticated API.
  /// This avoids relying on a public /storage symlink, which may be blocked
  /// by shared-hosting configuration even when the upload succeeded.
  Future<List<int>> avatarImageBytes({int? revision}) {
    final suffix = revision == null ? '' : '?v=$revision';
    return _api.downloadBytes('profile/avatar/image$suffix');
  }

  /// Any parameter left null keeps that value unchanged server-side —
  /// mirrors ProfileController::updateAppearance() on the Laravel side.
  Future<Map<String, dynamic>> updateAppearance({
    String? themeColor,
    String? themeColorSecondary,
    String? fontFamily,
    int? fontSize,
  }) async {
    final response = await _api.post('profile/appearance', {
      if (themeColor != null) 'theme_color': themeColor,
      if (themeColorSecondary != null) 'theme_color_secondary': themeColorSecondary,
      if (fontFamily != null) 'font_family': fontFamily,
      if (fontSize != null) 'font_size': fontSize,
    });
    return Map<String, dynamic>.from(response['data']);
  }

  /// Mirrors ProfileController::update() on the Laravel side — email
  /// changes reset verification status server-side, same as web.
  Future<Map<String, dynamic>> updateProfile({required String name, required String email}) async {
    final response = await _api.put('profile', {'name': name, 'email': email});
    return Map<String, dynamic>.from(response['data']);
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) =>
      _api.put('profile/password', {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });

  Future<String?> updateAvatar({
    required List<int> fileBytes,
    required String fileName,
    required String contentType,
  }) async {
    final response = await _api.postMultipart(
      'profile/avatar',
      fileFieldName: 'avatar',
      fileBytes: fileBytes,
      fileName: fileName,
      contentType: contentType,
    );

    final data = response is Map ? response['data'] : null;
    return data is Map ? data['avatar_url']?.toString() : null;
  }


  Future<Map<String, dynamic>> currencyPreference() async {
    final response = await _api.get('profile/currency');
    return Map<String, dynamic>.from(response['data'] ?? const {});
  }

  Future<Map<String, dynamic>> updateCurrencyPreference(String code) async {
    final response = await _api.put('profile/currency', {
      'preferred_currency_code': code.toUpperCase(),
    });
    return Map<String, dynamic>.from(response['data'] ?? const {});
  }

}
