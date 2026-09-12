import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/branding_service.dart';

class IncomesScreen extends StatefulWidget {
  const IncomesScreen({super.key});

  @override
  State<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = <String, dynamic>{};
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _money(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(
              value?.toString().replaceAll(',', '').trim() ?? '',
            ) ??
            0;

    return (BrandingService.cached ?? BrandingInfo(siteName: ''))
        .formatMoney(amount);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final responses = await Future.wait<dynamic>([
        ApiClient.instance.get(
          'incomes/stats',
          cacheable: false,
        ),
        ApiClient.instance.get(
          'incomes',
          cacheable: false,
        ),
      ]);

      final rawStats = responses[0];
      dynamic rawItems = responses[1];

      final stats = rawStats is Map
          ? Map<String, dynamic>.from(rawStats)
          : <String, dynamic>{};

      if (rawItems is Map && rawItems['data'] is List) {
        rawItems = rawItems['data'];
      }

      final items = rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _stats = stats;
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load Income right now.';
      });
    }
  }

  Widget _stat(
    String title,
    dynamic value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _money(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const ListView(
                children: [
                  SizedBox(height: 220),
                  Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              )
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 80),
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 52,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      28,
                    ),
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        crossAxisCount: width >= 800 ? 4 : 2,
                        childAspectRatio: 1.45,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          _stat(
                            'Total Income',
                            _stats['total_income'],
                            Icons.account_balance_wallet_outlined,
                          ),
                          _stat(
                            'Monthly Income',
                            _stats['monthly_income'],
                            Icons.calendar_month_outlined,
                          ),
                          _stat(
                            'Balance',
                            _stats['balance'],
                            Icons.scale_outlined,
                          ),
                          _stat(
                            'Total Income Out',
                            _stats['total_income_out'],
                            Icons.north_east_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Income entries',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (_items.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No Income has been recorded yet.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ..._items.map(
                          (item) => Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(
                                  Icons.payments_outlined,
                                ),
                              ),
                              title: Text(
                                item['source']?.toString() ??
                                    'Income',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  item['category'],
                                  item['received_at'],
                                ]
                                    .where(
                                      (value) =>
                                          value != null &&
                                          value
                                              .toString()
                                              .trim()
                                              .isNotEmpty,
                                    )
                                    .join(' • '),
                              ),
                              trailing: Text(
                                _money(item['amount']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
