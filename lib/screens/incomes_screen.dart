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

    final branding = BrandingService.cached ?? BrandingInfo(siteName: '');

    return branding.formatMoney(amount);
  }

  List<Map<String, dynamic>> _extractItems(dynamic response) {
    dynamic payload = response;

    if (payload is Map && payload['data'] != null) {
      payload = payload['data'];
    }

    if (payload is Map && payload['data'] is List) {
      payload = payload['data'];
    }

    if (payload is! List) {
      return <Map<String, dynamic>>[];
    }

    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Map<String, dynamic> _extractStats(dynamic response) {
    dynamic payload = response;

    if (payload is Map && payload['data'] is Map) {
      payload = payload['data'];
    }

    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }

    return <String, dynamic>{};
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

      if (!mounted) {
        return;
      }

      setState(() {
        _stats = _extractStats(responses[0]);
        _items = _extractItems(responses[1]);
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Could not load Income right now.';
      });
    }
  }

  Widget _statCard({
    required String title,
    required dynamic value,
    required IconData icon,
  }) {
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

  Widget _loadingView() {
    // ListView itself does not have a const constructor.
    // Keeping const only on its children fixes const_with_non_const.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 220),
        Center(
          child: CircularProgressIndicator(),
        ),
      ],
    );
  }

  Widget _errorView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.cloud_off_outlined,
          size: 52,
        ),
        const SizedBox(height: 14),
        Text(
          _error ?? 'Could not load Income right now.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );
  }

  Widget _contentView(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : 2;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        28,
      ),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          childAspectRatio: width < 380 ? 1.25 : 1.45,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _statCard(
              title: 'Total Income',
              value: _stats['total_income'],
              icon: Icons.account_balance_wallet_outlined,
            ),
            _statCard(
              title: 'Monthly Income',
              value: _stats['monthly_income'],
              icon: Icons.calendar_month_outlined,
            ),
            _statCard(
              title: 'Balance',
              value: _stats['balance'],
              icon: Icons.scale_outlined,
            ),
            _statCard(
              title: 'Total Income Out',
              value: _stats['total_income_out'],
              icon: Icons.north_east_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Income entries',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 36,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No Income has been recorded yet.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ..._items.map(_incomeTile),
      ],
    );
  }

  Widget _incomeTile(Map<String, dynamic> item) {
    final subtitle = <dynamic>[
      item['category'],
      item['received_at'],
    ]
        .where(
          (value) => value != null && value.toString().trim().isNotEmpty,
        )
        .map((value) => value.toString())
        .join(' • ');

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(
            Icons.payments_outlined,
          ),
        ),
        title: Text(
          item['source']?.toString().trim().isNotEmpty == true
              ? item['source'].toString()
              : 'Income',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: Text(
          _money(item['amount']),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Income'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? _loadingView()
            : _error != null
                ? _errorView()
                : _contentView(context),
      ),
    );
  }
}
