import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/currency_provider.dart';

class CurrencyText extends StatelessWidget {
  const CurrencyText(this.baseAmount, {super.key, this.style});
  final num baseAmount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    return Text(currency.formatFromBase(baseAmount), style: style);
  }
}
