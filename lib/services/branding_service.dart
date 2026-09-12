import 'package:flutter/foundation.dart';
import 'api_client.dart';

class BrandingInfo {
  final String siteName;
  final String? logoUrl;
  final String currencySymbol;
  final int currencyDecimals;
  final double currencyRate;
  final String currencyCode;

  BrandingInfo({
    required this.siteName,
    this.logoUrl,
    this.currencySymbol = 'UGX',
    this.currencyDecimals = 0,
    this.currencyRate = 1.0,
    this.currencyCode = 'UGX',
  });

  factory BrandingInfo.fromJson(Map<String, dynamic> json) => BrandingInfo(
        siteName: json['site_name'] ?? 'My Digital Diary',
        logoUrl: json['logo_url'],
        currencySymbol: json['currency_symbol'] ?? 'UGX',
        currencyDecimals: json['currency_decimals'] ?? 0,
        currencyRate: 1.0,
        currencyCode: (json['currency_code'] ?? 'UGX').toString().toUpperCase(),
      );

  String formatMoney(num amount) {
    final converted = currencyRate > 0 ? amount / currencyRate : amount;
    return '$currencySymbol ${converted.toStringAsFixed(currencyDecimals)}';
  }

  BrandingInfo copyWithDisplayCurrency({
    required String code,
    required String symbol,
    required double rate,
    required int decimals,
  }) =>
      BrandingInfo(
        siteName: siteName,
        logoUrl: logoUrl,
        currencySymbol: symbol,
        currencyDecimals: decimals,
        currencyRate: rate <= 0 ? 1.0 : rate,
        currencyCode: code.toUpperCase(),
      );
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

  /// Sync the authenticated user's display-currency preference from Laravel.
  /// Base amounts in the mobile app are stored in the site's base currency;
  /// additional-currency rates mean base units per 1 foreign unit, so display
  /// conversion divides by the configured rate just like the web app.
  Future<BrandingInfo?> syncPreferredCurrency() async {
    try {
      final response = await _api.get('profile/currency');
      final data = Map<String, dynamic>.from(response['data'] ?? const {});
      applyCurrencyPreference(data);
      return _cached;
    } catch (e) {
      debugPrint('BrandingService: preferred currency sync failed — $e');
      return _cached;
    }
  }

  static void applyCurrencyPreference(Map<String, dynamic> data) {
    final selected = (data['selected'] ?? '').toString().toUpperCase();
    final options = (data['options'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (selected.isEmpty || options.isEmpty) return;

    Map<String, dynamic>? match;
    for (final option in options) {
      if ((option['code'] ?? '').toString().toUpperCase() == selected) {
        match = option;
        break;
      }
    }
    if (match == null) return;

    final current = _cached ?? BrandingInfo(siteName: 'My Digital Diary');
    final rate = double.tryParse((match['rate'] ?? '1').toString()) ?? 1.0;
    final isBase = rate == 1.0;
    _cached = current.copyWithDisplayCurrency(
      code: selected,
      symbol: (match['symbol'] ?? selected).toString(),
      rate: rate,
      decimals: isBase ? current.currencyDecimals : 2,
    );
  }

  Future<BrandingInfo?> fetch() async {
    if (_cached != null) return _cached;
    try {
      final response = await _api.get('branding', auth: false);
      _cached = BrandingInfo.fromJson(response['data']);
      debugPrint(
          'BrandingService: fetched OK — logo_url = ${_cached?.logoUrl}');
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
