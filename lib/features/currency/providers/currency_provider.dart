import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../services/api_client.dart';
import '../models/currency_config.dart';
import '../services/currency_service.dart';

class CurrencyProvider extends ChangeNotifier {
  CurrencyProvider({ApiClient? api})
      : _service = CurrencyService(api ?? ApiClient.instance);

  static const _storage = FlutterSecureStorage();
  static const _key = 'selected_display_currency';

  final CurrencyService _service;

  CurrencyConfig? config;
  String selectedCurrency = 'UGX';
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      try {
        selectedCurrency = await _storage.read(key: _key) ?? selectedCurrency;
      } on PlatformException catch (e) {
        /*
         * A broken/old Android encrypted-storage key must not prevent
         * currency settings—or the whole app—from loading. The backend
         * default currency remains the safe fallback.
         */
        debugPrint(
          'CurrencyProvider: unable to read saved currency preference: $e',
        );
      }

      config = await _service.fetch(currency: selectedCurrency);

      /*
       * Laravel is authoritative. If a saved currency is no longer
       * supported or user selection is disabled, use the currency returned
       * by the API instead.
       */
      selectedCurrency = config!.displayCurrency;
    } catch (e) {
      error = e.toString();
      debugPrint('CurrencyProvider.load failed: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectCurrency(String code) async {
    final requested = code.trim().toUpperCase();

    if (requested.isEmpty) {
      return;
    }

    if (requested == selectedCurrency && config != null) {
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      /*
       * Fetching again is important: Laravel returns the current live/cached
       * conversion rate for the newly selected display currency.
       */
      final fresh = await _service.fetch(currency: requested);

      config = fresh;
      selectedCurrency = fresh.displayCurrency;

      try {
        await _storage.write(
          key: _key,
          value: selectedCurrency,
        );
      } on PlatformException catch (e) {
        /*
         * Keep the new currency in memory even when secure storage cannot
         * persist it. This mirrors the app's startup-safe token handling.
         */
        debugPrint(
          'CurrencyProvider: unable to save currency preference: $e',
        );
      }
    } catch (e) {
      error = e.toString();
      debugPrint('CurrencyProvider.selectCurrency failed: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRate() async {
    try {
      final fresh = await _service.fetch(
        currency: selectedCurrency,
      );

      config = fresh;
      selectedCurrency = fresh.displayCurrency;
      error = null;
    } catch (e) {
      error = e.toString();
      debugPrint('CurrencyProvider.refreshRate failed: $e');
    } finally {
      notifyListeners();
    }
  }

  double convertFromBase(num amount) {
    return amount.toDouble() * (config?.rate ?? 1);
  }

  String formatFromBase(num amount) {
    final value = convertFromBase(amount);

    final meta = config?.currencies[selectedCurrency];

    final symbol = meta?.symbol ?? selectedCurrency;
    final decimals = meta?.decimals ?? (selectedCurrency == 'UGX' ? 0 : 2);

    return '$symbol ${_formatNumber(value, decimals)}';
  }

  String _formatNumber(double value, int decimals) {
    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');

    final negative = parts.first.startsWith('-');
    var whole = negative ? parts.first.substring(1) : parts.first;

    final buffer = StringBuffer();

    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(whole[i]);
    }

    final prefix = negative ? '-' : '';
    final fraction = parts.length > 1 && decimals > 0 ? '.${parts[1]}' : '';

    return '$prefix$buffer$fraction';
  }
}
