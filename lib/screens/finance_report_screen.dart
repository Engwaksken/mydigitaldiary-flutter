import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/module_configs.dart';
import '../models/dynamic_item.dart';
import '../services/api_client.dart';
import 'dynamic_crud_screen.dart';
import 'expenses_screen.dart';

class FinanceReportScreen extends StatefulWidget {
  final String endpoint;
  final String title;
  final Map<String, dynamic>? initialSummary;

  const FinanceReportScreen(
      {super.key,
      required this.endpoint,
      required this.title,
      this.initialSummary});

  @override
  State<FinanceReportScreen> createState() => _FinanceReportScreenState();
}

class _FinanceReportScreenState extends State<FinanceReportScreen> {
  final _search = TextEditingController();
  String _period = 'month';
  DateTime? _from;
  DateTime? _to;
  bool _loading = true;
  int _page = 1;
  int _lastPage = 1;
  List<DynamicItem> _items = [];
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      if (_summary == null) {
        final dash = await ApiClient.instance.get('dashboard', cacheable: true);
        final finance = dash['finance_summary'];
        if (finance is Map) {
          for (final value in finance.values) {
            if (value is Map &&
                value['endpoint']?.toString() == widget.endpoint) {
              _summary = Map<String, dynamic>.from(value);
              break;
            }
          }
        }
      }
      final query = <String>[
        'page=$page',
        'period=$_period',
        if (_search.text.trim().isNotEmpty)
          'q=${Uri.encodeQueryComponent(_search.text.trim())}',
        if (_period == 'custom' && _from != null) 'from=${_date(_from!)}',
        if (_period == 'custom' && _to != null) 'to=${_date(_to!)}',
      ].join('&');
      final response =
          await ApiClient.instance.get('${widget.endpoint}?$query');
      final rows = ((response['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => DynamicItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _page = (response['current_page'] as num?)?.toInt() ?? page;
        _lastPage = (response['last_page'] as num?)?.toInt() ?? 1;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (range == null) return;
    setState(() {
      _period = 'custom';
      _from = range.start;
      _to = range.end;
    });
    _load();
  }

  void _openManage() {
    if (widget.endpoint == 'expenses') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DynamicCrudScreen(
                config: moduleConfigByEndpoint(widget.endpoint))));
  }

  String _money(dynamic value) {
    final number =
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return 'UGX ${NumberFormat('#,##0.##').format(number)}';
  }

  String _titleFor(DynamicItem item) {
    for (final key in [
      'source',
      'category',
      'person_name',
      'name',
      'title',
      'type'
    ]) {
      final value = item[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return widget.title;
  }

  String _subtitleFor(DynamicItem item) {
    for (final key in [
      'received_at',
      'spent_at',
      'contributed_at',
      'date',
      'target_date',
      'due_date',
      'created_at'
    ]) {
      final raw = item[key]?.toString();
      if (raw == null || raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return DateFormat('d MMM y').format(parsed);
      return raw;
    }
    return '';
  }

  String? _amountFor(DynamicItem item) {
    for (final key in ['amount', 'target_amount']) {
      if (item[key] != null) return _money(item[key]);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} Report')),
      body: RefreshIndicator(
        onRefresh: () => _load(page: _page),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (summary != null) ...[
              Row(children: [
                Expanded(
                    child: _SummaryCard(
                        label: 'This month',
                        value: _money(summary['monthly_total']))),
                const SizedBox(width: 10),
                Expanded(
                    child: _SummaryCard(
                        label: summary['overall_label']?.toString() ??
                            'Overall total',
                        value: _money(summary['overall_total']))),
              ]),
              const SizedBox(height: 10),
              Text('${summary['count'] ?? 0} records',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search ${widget.title.toLowerCase()}',
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _load();
                        }),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  'today': 'Today',
                  'week': 'This week',
                  'month': 'This month',
                  'last_month': 'Last month',
                  'year': 'This year'
                }.entries)
                  ChoiceChip(
                      label: Text(entry.value),
                      selected: _period == entry.key,
                      onSelected: (_) {
                        setState(() {
                          _period = entry.key;
                          _from = null;
                          _to = null;
                        });
                        _load();
                      }),
                ActionChip(
                    avatar: const Icon(Icons.date_range, size: 16),
                    label: Text(_period == 'custom' &&
                            _from != null &&
                            _to != null
                        ? '${DateFormat('d MMM').format(_from!)} – ${DateFormat('d MMM').format(_to!)}'
                        : 'Custom'),
                    onPressed: _pickRange),
                ActionChip(
                    avatar: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Reset'),
                    onPressed: () {
                      _search.clear();
                      setState(() {
                        _period = 'month';
                        _from = null;
                        _to = null;
                      });
                      _load();
                    }),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()))
            else if (_items.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(30),
                  child:
                      Center(child: Text('No records found for this period.')))
            else
              ..._items.asMap().entries.expand((entry) sync* {
                final item = entry.value;
                yield _FinanceReportRow(
                  title: _titleFor(item),
                  subtitle: _subtitleFor(item),
                  amount: _amountFor(item),
                );
                if (entry.key < _items.length - 1) {
                  yield const SizedBox(height: 12);
                }
              }),
            if (!_loading && _lastPage > 1) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                    icon: const Icon(Icons.chevron_left)),
                Text('Page $_page of $_lastPage'),
                IconButton(
                    onPressed:
                        _page < _lastPage ? () => _load(page: _page + 1) : null,
                    icon: const Icon(Icons.chevron_right)),
              ]),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _openManage,
                icon: const Icon(Icons.edit_note),
                label: Text('Manage ${widget.title}')),
          ],
        ),
      ),
    );
  }
}

class _FinanceReportRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? amount;

  const _FinanceReportRow({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Untitled record' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (amount != null && amount!.isNotEmpty) ...[
            const SizedBox(width: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Text(
                amount!,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: .35),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 5),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800))),
        ]),
      );
}
