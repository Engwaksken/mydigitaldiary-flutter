import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/currency_provider.dart';

class CurrencySettingsScreen extends StatelessWidget {
  const CurrencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final config = currency.config;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency'),
      ),
      body: RefreshIndicator(
        onRefresh: currency.refreshRate,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Display currency',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your saved amounts remain in the system base currency. '
              'My Digital Diary converts them using the latest exchange rate.',
            ),
            const SizedBox(height: 20),
            if (currency.loading && config == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (config == null)
              _CurrencyLoadError(
                message: currency.error ?? 'Currency settings are unavailable.',
                onRetry: currency.load,
              )
            else ...[
              DropdownButtonFormField<String>(
                /*
                 * Flutter 3.33+ deprecated value: for form fields.
                 * initialValue is the supported replacement.
                 *
                 * The key forces a fresh form-field state if Laravel returns
                 * a different authoritative display currency.
                 */
                key: ValueKey<String>(
                  'currency-${currency.selectedCurrency}',
                ),
                initialValue: currency.selectedCurrency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  border: OutlineInputBorder(),
                ),
                items: config.currencies.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          '${entry.key} — ${entry.value.name}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: config.allowUserSelection && !currency.loading
                    ? (value) async {
                        if (value == null) {
                          return;
                        }

                        await currency.selectCurrency(value);
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.currency_exchange,
                  ),
                  title: Text(
                    currency.selectedCurrency == config.baseCurrency
                        ? '1 ${config.baseCurrency} = '
                            '1 ${config.displayCurrency}'
                        : '1 ${config.baseCurrency} = '
                            '${config.rate.toStringAsFixed(8)} '
                            '${currency.selectedCurrency}',
                  ),
                  subtitle: const Text(
                    'Current exchange rate supplied by My Digital Diary.',
                  ),
                  trailing: currency.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : IconButton(
                          tooltip: 'Refresh exchange rate',
                          onPressed: currency.refreshRate,
                          icon: const Icon(Icons.refresh),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              _ConversionExample(
                label: 'Example',
                base: '1,000,000 ${config.baseCurrency}',
                converted: currency.formatFromBase(1000000),
              ),
              if (currency.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  currency.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversionExample extends StatelessWidget {
  const _ConversionExample({
    required this.label,
    required this.base,
    required this.converted,
  });

  final String label;
  final String base;
  final String converted;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$base → $converted',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyLoadError extends StatelessWidget {
  const _CurrencyLoadError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
