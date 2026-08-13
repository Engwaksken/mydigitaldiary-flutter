import 'package:flutter/foundation.dart';
import 'api_client.dart';

class BrandingInfo {
  final String siteName;
  final String? logoUrl;
  final String currencySymbol;
  final int currencyDecimals;

  BrandingInfo({
    required this.siteName,
    this.logoUrl,
    this.currencySymbol = 'UGX',
    this.currencyDecimals = 0,
  });

  factory BrandingInfo.fromJson(Map<String, dynamic> json) => BrandingInfo(
        siteName: json['site_name'] ?? 'My Digital Diary',
        logoUrl: json['logo_url'],
        currencySymbol: json['currency_symbol'] ?? 'UGX',
        currencyDecimals: json['currency_decimals'] ?? 0,
      );

  String formatMoney(num amount) {
    return '$currencySymbol ${amount.toStringAsFixed(currencyDecimals)}';
  }
}

/// Public endpoint — no auth token needed, since login/register/splash
/// screens need the logo before any token exists.
class BrandingService {
  final _api = ApiClient.instance;
  static BrandingInfo? _cached;

  /// Synchronous access to whatever was last fetched — null until the
  /// first successful fetch() call anywhere in the app (e.g. from the
  /// splash or login screen, which both call this on startup).
  static BrandingInfo? get cached => _cached;

  Future<BrandingInfo?> fetch() async {
    if (_cached != null) return _cached;
    try {
      final response = await _api.get('branding', auth: false);
      _cached = BrandingInfo.fromJson(response['data']);
      debugPrint('BrandingService: fetched OK — logo_url = ${_cached?.logoUrl}');
      return _cached;
    } catch (e) {
      // Falls back to null — every screen using this shows a local
      // icon/text fallback, so a failed fetch (offline, server
      // hiccup) never blocks someone from reaching the login form.
      // Logged (not silent) so a PERSISTENT failure is actually
      // visible in the debug console instead of just looking like
      // "the logo never shows up" with no clue why.
      debugPrint('BrandingService: fetch failed — $e');
      return null;
    }
  }
}
