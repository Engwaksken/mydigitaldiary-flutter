import '../../../services/api_client.dart';
import '../models/currency_config.dart';

class CurrencyService {
  CurrencyService(this._api);
  final ApiClient _api;

  Future<CurrencyConfig> fetch({String? currency}) async {
    final suffix = currency == null || currency.isEmpty
        ? ''
        : '?currency=${Uri.encodeQueryComponent(currency)}';

    final response = await _api.get('currency$suffix', cacheable: false);
    final root = (response as Map).cast<String, dynamic>();
    final data = (root['data'] as Map?)?.cast<String, dynamic>() ?? root;
    return CurrencyConfig.fromJson(data);
  }
}
