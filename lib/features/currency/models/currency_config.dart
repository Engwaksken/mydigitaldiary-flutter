class CurrencyMeta {
  const CurrencyMeta({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimals,
  });

  final String code;
  final String name;
  final String symbol;
  final int decimals;

  factory CurrencyMeta.fromJson(String code, Map<String, dynamic> json) {
    return CurrencyMeta(
      code: code,
      name: (json['name'] ?? code).toString(),
      symbol: (json['symbol'] ?? code).toString(),
      decimals: int.tryParse('${json['decimals'] ?? 2}') ?? 2,
    );
  }
}

class CurrencyConfig {
  const CurrencyConfig({
    required this.baseCurrency,
    required this.displayCurrency,
    required this.rate,
    required this.allowUserSelection,
    required this.currencies,
  });

  final String baseCurrency;
  final String displayCurrency;
  final double rate;
  final bool allowUserSelection;
  final Map<String, CurrencyMeta> currencies;

  factory CurrencyConfig.fromJson(Map<String, dynamic> json) {
    final raw = (json['currencies'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CurrencyConfig(
      baseCurrency: (json['base_currency'] ?? 'UGX').toString(),
      displayCurrency: (json['display_currency'] ?? 'UGX').toString(),
      rate: double.tryParse('${json['rate'] ?? 1}') ?? 1,
      allowUserSelection: json['allow_user_selection'] == true ||
          json['allow_user_selection'] == 1,
      currencies: raw.map(
        (key, value) => MapEntry(
          key,
          CurrencyMeta.fromJson(key, (value as Map).cast<String, dynamic>()),
        ),
      ),
    );
  }
}
