import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../services/api_client.dart';
import '../features/workspace/presentation/workspace_members_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _service = SubscriptionService();
  Map<String, dynamic>? _status;
  List<SubscriptionPlanInfo> _plans = [];
  List<PaymentGatewayInfo> _gateways = [];
  List<PaymentRecord> _payments = [];
  int _billingPage = 1;
  int _billingLastPage = 1;
  int _billingPerPage = 10;
  int _billingTotal = 0;
  int? _billingFrom;
  int? _billingTo;
  bool _loading = true;
  bool _billingLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? billingPage}) async {
    final targetPage = billingPage ?? _billingPage;

    if (billingPage == null) {
      setState(() => _loading = true);
    } else {
      setState(() => _billingLoading = true);
    }

    try {
      final results = await Future.wait<dynamic>([
        _service.status(),
        _service.plans(),
        _service.gateways(),
        _service.payments(
          page: targetPage,
          perPage: _billingPerPage,
        ),
      ]);

      final status = results[0] as Map<String, dynamic>;
      final plans = results[1] as List<SubscriptionPlanInfo>;
      final serverGateways = results[2] as List<PaymentGatewayInfo>;
      final payments = results[3];

      IoTecGatewayOptions? ioTecOptions;
      try {
        ioTecOptions = await _service.ioTecOptions();
      } catch (_) {
        // Keep the standard gateway list usable even if the optional ioTec
        // capabilities endpoint is temporarily unavailable.
      }

      final gateways = _mergeIoTecPaymentMethods(
        serverGateways,
        ioTecOptions,
      );

      if (!mounted) return;
      setState(() {
        _status = status;
        _plans = plans;
        _gateways = gateways;
        _payments = payments.data;
        _billingPage = payments.currentPage;
        _billingLastPage = payments.lastPage;
        _billingPerPage = payments.perPage;
        _billingTotal = payments.total;
        _billingFrom = payments.from;
        _billingTo = payments.to;
        _loading = false;
        _billingLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _billingLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  List<PaymentGatewayInfo> _mergeIoTecPaymentMethods(
    List<PaymentGatewayInfo> serverGateways,
    IoTecGatewayOptions? options,
  ) {
    final gateways = List<PaymentGatewayInfo>.from(serverGateways);

    if (options == null || !options.enabled) {
      return gateways;
    }

    final hasMobileMoney = gateways.any(
      (gateway) => gateway.type == 'mobile_money' || gateway.collectsAutomatically,
    );

    final hasCard = gateways.any(
      (gateway) => gateway.type == 'card' ||
          gateway.name.toLowerCase().contains('visa') ||
          gateway.name.toLowerCase().contains('mastercard'),
    );

    if (options.supportsMobileMoney && !hasMobileMoney) {
      gateways.insert(
        0,
        PaymentGatewayInfo(
          id: -901,
          type: 'mobile_money',
          name: 'Mobile Money',
          collectsAutomatically: true,
          supportsMtn: true,
          supportsAirtel: true,
          providerName: 'ioTec',
        ),
      );
    }

    if (options.supportsCard && !hasCard) {
      gateways.add(
        PaymentGatewayInfo(
          id: -902,
          type: 'card',
          name: 'Visa / MasterCard',
          collectsAutomatically: false,
          supportsMtn: false,
          supportsAirtel: false,
          providerName: 'ioTec',
        ),
      );
    }

    return gateways;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  SubscriptionPlanInfo? get _activePlan {
    final status = _status;
    if (status == null || _plans.isEmpty) return null;

    final activeId = _asInt(
      status['subscription_plan_id'] ??
          status['plan_id'] ??
          status['current_plan_id'],
    );

    if (activeId != null) {
      for (final plan in _plans) {
        if (plan.id == activeId) return plan;
      }
    }

    final currentName = (status['subscription_plan'] ??
            status['plan_name'] ??
            status['current_plan'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    if (currentName.isEmpty) return null;

    for (final plan in _plans) {
      final planName = plan.name.trim().toLowerCase();
      if (currentName == planName ||
          currentName.startsWith('$planName —') ||
          currentName.startsWith('$planName -') ||
          currentName.contains(planName)) {
        return plan;
      }
    }

    return null;
  }

  bool get _hasMemberManagement {
    final status = _status;
    if (status == null) return false;

    final subscriptionStatus = (status['subscription_status'] ??
            status['status'] ??
            '')
        .toString()
        .toLowerCase();

    if (subscriptionStatus.isNotEmpty &&
        !['active', 'trial', 'trialing'].contains(subscriptionStatus)) {
      return false;
    }

    final activePlan = _activePlan;
    if (activePlan != null) {
      return !activePlan.isIndividual && activePlan.includedMembers > 1;
    }

    final currentName = (status['subscription_plan'] ?? '')
        .toString()
        .toLowerCase();

    return currentName.contains('family') ||
        currentName.contains('team') ||
        currentName.contains('organization') ||
        currentName.contains('organisation') ||
        currentName.contains('member');
  }

  int? get _activeSeatLimit {
    final fromStatus = _asInt(
      _status?['included_members'] ??
          _status?['seat_limit'] ??
          _status?['member_limit'],
    );

    if (fromStatus != null && fromStatus > 1) return fromStatus;

    final plan = _activePlan;
    if (plan != null && plan.includedMembers > 1) {
      return plan.includedMembers;
    }

    return null;
  }

  Future<void> _openMemberManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const WorkspaceMembersScreen(),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  Future<void> _loadBillingPage(int page) async {
    if (page < 1 || page > _billingLastPage || _billingLoading) return;
    await _load(billingPage: page);
  }

  Future<void> _openDownload(String? url) async {
    final value = url?.trim();
    if (value == null || value.isEmpty) return;

    final uri = Uri.tryParse(value);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Map<String, dynamic>? get _valueSummary {
    final status = _status;
    if (status == null) return null;

    dynamic raw = status['value_summary'] ??
        status['monthly_value'] ??
        status['value_this_month'] ??
        status['monthly_review'];

    if (raw is Map && raw['value_summary'] is Map) {
      raw = raw['value_summary'];
    }

    if (raw is! Map) return null;

    final source = Map<String, dynamic>.from(raw);

    dynamic first(List<String> keys, [dynamic fallback = 0]) {
      for (final key in keys) {
        final value = source[key];
        if (value != null) return value;
      }
      return fallback;
    }

    return <String, dynamic>{
      'tasks_completed': first([
        'tasks_completed',
        'completed_tasks',
        'tasks',
        'task_count',
      ]),
      'expenses_tracked': first([
        'expenses_tracked',
        'expenses',
        'expense_total',
        'total_expenses',
      ]),
      'saved': first([
        'saved',
        'savings',
        'amount_saved',
        'savings_total',
      ]),
      'ai_plans': first([
        'ai_plans',
        'ai_plan_count',
        'plans_generated',
      ]),
      'meetings': first([
        'meetings',
        'meeting_count',
        'meetings_count',
      ]),
    };
  }

  Widget _buildMemberManagementCard() {
    final plan = _activePlan;
    final limit = _activeSeatLimit;
    final planName = plan?.name ??
        (_status?['subscription_plan'] ?? 'Team plan').toString();

    return Card(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      color: const Color(0xFFF0FDFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF99F6E4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.groups_2_outlined,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage your members',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        limit != null
                            ? '$planName includes up to $limit members. Invite people and assign their workspace roles.'
                            : '$planName supports member management. Invite people and assign their workspace roles.',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openMemberManagement,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add & Assign Members'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedPlans() {
    const categories = ['individual', 'family_team', 'organization'];
    final widgets = <Widget>[];

    for (final category in categories) {
      final plansInCategory = _plans.where((p) => p.category == category).toList();
      if (plansInCategory.isEmpty) continue;

      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          plansInCategory.first.categoryLabel().toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
        ),
      ));

      // Enterprise is sales-assisted, not self-serve — same reasoning
      // as the web app's pricing page: no pricing cards here, just a
      // prompt that opens the same "Contact Sales" form (in an external
      // browser, since that form's country search/benefits grid isn't
      // worth rebuilding natively for a page most people see once).
      if (category == 'organization') {
        widgets.add(_buildContactSalesCard());
      } else if (category == 'individual') {
        final primary = plansInCategory.where((p) => p.durationMonths == 1 || p.durationMonths == 12).toList();
        final shown = primary.isNotEmpty ? primary : plansInCategory.take(2).toList();
        widgets.addAll(shown.map(_buildPlanCard));
        final shownIds = shown.map((p) => p.id).toSet();
        final more = plansInCategory.where((p) => !shownIds.contains(p.id)).toList();
        if (more.isNotEmpty) {
          widgets.add(ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('More billing options', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            children: more.map(_buildPlanCard).toList(),
          ));
        }
      } else {
        widgets.addAll(plansInCategory.map(_buildPlanCard));
      }
    }

    return widgets;
  }

  Widget _buildContactSalesCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: const Color(0xFFF5F3FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFDDD6FE))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Built for larger teams', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4C1D95))),
            const SizedBox(height: 4),
            const Text(
              "Custom seats, pricing, and onboarding for bigger organizations — talk to us and we'll put together something that fits.",
              style: TextStyle(color: Color(0xFF5B21B6), fontSize: 13),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _openContactSales,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9), foregroundColor: Colors.white),
              icon: const Icon(Icons.handshake_outlined, size: 18),
              label: const Text('Contact Sales'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openContactSales() async {
    final base = ApiClient.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final uri = Uri.tryParse('$base/enterprise/contact');
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  ({Color background, Color border, Color text}) _stickyColors(int months) {
    if (months <= 1) {
      return (background: const Color(0xFFFFF8C5), border: const Color(0xFFE7CF62), text: const Color(0xFF5F5112));
    }
    if (months <= 3) {
      return (background: const Color(0xFFDFF4FF), border: const Color(0xFF8BC9E8), text: const Color(0xFF155B7A));
    }
    if (months <= 6) {
      return (background: const Color(0xFFF3E5FF), border: const Color(0xFFC9A5ED), text: const Color(0xFF63398A));
    }
    if (months <= 12) {
      return (background: const Color(0xFFDFF6E8), border: const Color(0xFF8BCDA5), text: const Color(0xFF16613A));
    }
    return (background: const Color(0xFFFFE8E2), border: const Color(0xFFEAB0A0), text: const Color(0xFF7D3E30));
  }

  Widget _buildPlanCard(SubscriptionPlanInfo plan) {
    final sticky = _stickyColors(plan.durationMonths ?? 0);
    final color = sticky.text;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: sticky.border, width: 1.7)),
      color: sticky.background,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openCheckout(plan),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(plan.name, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
                  if (plan.isRecommended || plan.isBestValue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        plan.isRecommended ? 'RECOMMENDED' : 'BEST VALUE',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (plan.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                      child: Text(plan.badge!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(plan.formattedPrice(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(
                plan.isLifetime ? 'One-time payment' : 'every ${plan.durationMonths} month(s)',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              if (!plan.isIndividual) ...[
                const Divider(height: 10),
                Text(
                  '${plan.includedMembers} members included${plan.pricePerMember != null ? ' (${plan.currencySymbol} ${plan.pricePerMember!.toStringAsFixed(0)}/member)' : ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
                if (plan.additionalMemberPrice != null)
                  Text(
                    '+${plan.currencySymbol} ${plan.additionalMemberPrice!.toStringAsFixed(0)}/member beyond that',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(72, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _openCheckout(plan),
                  child: const Text('Choose', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCheckout(SubscriptionPlanInfo plan) {
    if (_gateways.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No payment methods are configured yet.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CheckoutSheet(
        plan: plan,
        gateways: _gateways,
        service: _service,
        initialPhone: _status?['account_phone']?.toString(),
        onDone: _load,
      ),
    );
  }

  void _openPendingPayment(PaymentRecord payment) {
    final available = _gateways
        .where((g) => g.collectsAutomatically || g.type == 'bank')
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Mobile Money or bank transfer payment method is configured.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PendingPaymentSheet(
        payment: payment,
        gateways: available,
        service: _service,
        accountPhone: payment.contactPhone ?? _status?['account_phone']?.toString(),
        onDone: () => _load(billingPage: _billingPage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_status != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Plan', style: Theme.of(context).textTheme.labelMedium),
                            Text(_status!['subscription_plan'] ?? 'None', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              _status!['has_active_access'] == true ? 'Active' : 'Inactive',
                              style: TextStyle(color: _status!['has_active_access'] == true ? Colors.green : Colors.red),
                            ),
                            if (_status!['days_remaining'] != null)
                              Text(
                                '${_status!['days_remaining']} day(s) remaining',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            if ((_status!['expiry_date'] ?? _status!['subscription_expires_at']) != null)
                              Text('Expires: ${(_status!['expiry_date'] ?? _status!['subscription_expires_at']).toString().substring(0, 10)}'),
                            const SizedBox(height: 6),
                            Text(
                              'Payment phone: ${(_status!['account_phone'] ?? 'Not set yet')}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_hasMemberManagement) ...[
                    _buildMemberManagementCard(),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 10),
                  if (_valueSummary != null)
                    _SubscriptionValueCard(summary: _valueSummary!),
                  const SizedBox(height: 10),
                  Text('Choose your plan', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  const Text('Monthly and Annual are shown first. Open More billing options for other durations.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  ..._buildGroupedPlans(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Invoices & Receipts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      DropdownButton<int>(
                        value: _billingPerPage,
                        underline: const SizedBox.shrink(),
                        items: const [10, 25, 50, 100]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value / page'),
                              ),
                            )
                            .toList(),
                        onChanged: _billingLoading
                            ? null
                            : (value) async {
                                if (value == null) return;
                                setState(() {
                                  _billingPerPage = value;
                                  _billingPage = 1;
                                });
                                await _load(billingPage: 1);
                              },
                      ),
                    ],
                  ),
                  if (_status?['account_phone'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Account payment phone: ${_status!['account_phone']}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_billingLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_payments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No invoices or payments yet.'),
                    )
                  else ...[
                    ..._payments.map(
                      (payment) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          payment.plan ?? 'Subscription',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${payment.currency} ${payment.amount.toStringAsFixed(0)} · ${payment.status}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: payment.isPending
                                                ? Colors.orange.shade800
                                                : payment.status == 'completed'
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (payment.isPending)
                                    FilledButton.icon(
                                      onPressed: () => _openPendingPayment(payment),
                                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                                      label: const Text('Pay now'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    'Method: ${payment.gatewayName ?? payment.method.replaceAll('_', ' ')}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  Text(
                                    'Phone: ${payment.contactPhone ?? _status?['account_phone'] ?? '—'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  Text(
                                    'Date: ${payment.createdAt.length >= 10 ? payment.createdAt.substring(0, 10) : payment.createdAt}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (payment.invoiceDownloadUrl != null)
                                    TextButton.icon(
                                      onPressed: () => _openDownload(payment.invoiceDownloadUrl),
                                      icon: const Icon(Icons.receipt_long, size: 18),
                                      label: const Text('Invoice'),
                                    ),
                                  if (payment.receiptDownloadUrl != null)
                                    TextButton.icon(
                                      onPressed: () => _openDownload(payment.receiptDownloadUrl),
                                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                                      label: const Text('Receipt'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_billingTotal > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 12),
                        child: Column(
                          children: [
                            Text(
                              'Showing ${_billingFrom ?? 0}–${_billingTo ?? 0} of $_billingTotal',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Previous page',
                                  onPressed: _billingPage > 1
                                      ? () => _loadBillingPage(_billingPage - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text('Page $_billingPage of $_billingLastPage'),
                                IconButton(
                                  tooltip: 'Next page',
                                  onPressed: _billingPage < _billingLastPage
                                      ? () => _loadBillingPage(_billingPage + 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ]
                ],
              ),
            ),
    );
  }
}


class _SubscriptionValueCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _SubscriptionValueCard({required this.summary});
  String _money(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'UGX ${amount.toStringAsFixed(0)}';
  }
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFECFDF5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your value this month', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          const Text('A quick look at what My Digital Diary is already helping you manage.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          Wrap(spacing: 18, runSpacing: 10, children: [
            _ValueMetric(label: 'Tasks', value: '${summary['tasks_completed'] ?? 0}'),
            _ValueMetric(label: 'Expenses', value: _money(summary['expenses_tracked'])),
            _ValueMetric(label: 'Saved', value: _money(summary['saved'])),
            _ValueMetric(label: 'AI plans', value: '${summary['ai_plans'] ?? 0}'),
            _ValueMetric(label: 'Meetings', value: '${summary['meetings'] ?? 0}'),
          ]),
        ]),
      ),
    );
  }
}

class _ValueMetric extends StatelessWidget {
  final String label;
  final String value;
  const _ValueMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => SizedBox(width: 92, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
  ]));
}

class _CheckoutSheet extends StatefulWidget {
  final SubscriptionPlanInfo plan;
  final List<PaymentGatewayInfo> gateways;
  final SubscriptionService service;
  final String? initialPhone;
  final VoidCallback onDone;

  const _CheckoutSheet({
    required this.plan,
    required this.gateways,
    required this.service,
    this.initialPhone,
    required this.onDone,
  });

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  late PaymentGatewayInfo _selectedGateway = widget.gateways.first;
  late final TextEditingController _phoneController;
  final _referenceController = TextEditingController();
  String _network = 'mtn';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _showIoTecConfirmation({
    required IoTecPaymentStart started,
    required bool isCard,
  }) async {
    if (!mounted || started.transactionId == null) return;

    Navigator.of(context).pop();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IoTecPaymentConfirmationDialog(
        service: widget.service,
        transactionId: started.transactionId!,
        isCard: isCard,
        initialMessage: started.message,
        onConfirmed: widget.onDone,
      ),
    );
  }

  Future<void> _pay() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_selectedGateway.type == 'card') {
        final started = await widget.service.payWithIoTecCard(
          widget.plan.id,
        );

        if (!started.success || started.transactionId == null) {
          setState(() {
            _error = started.message.isEmpty
                ? 'Could not start the Visa / MasterCard payment.'
                : started.message;
            _submitting = false;
          });
          return;
        }

        final redirect = started.redirectUrl?.trim();
        final uri = redirect == null || redirect.isEmpty
            ? null
            : Uri.tryParse(redirect);

        if (uri == null || !await canLaunchUrl(uri)) {
          setState(() {
            _error =
                'ioTec did not return a valid secure card checkout URL.';
            _submitting = false;
          });
          return;
        }

        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          setState(() {
            _error = 'Could not open the secure ioTec card checkout.';
            _submitting = false;
          });
          return;
        }

        await _showIoTecConfirmation(
          started: started,
          isCard: true,
        );
        return;
      }

      if (_selectedGateway.collectsAutomatically) {
        final phone = _phoneController.text.trim();

        if (phone.isEmpty) {
          setState(() {
            _error = 'Enter your phone number.';
            _submitting = false;
          });
          return;
        }

        final started = await widget.service.payWithIoTecMobileMoney(
          widget.plan.id,
          phone,
        );

        if (!started.success || started.transactionId == null) {
          setState(() {
            _error = started.message.isEmpty
                ? 'Could not start the Mobile Money payment.'
                : started.message;
            _submitting = false;
          });
          return;
        }

        await _showIoTecConfirmation(
          started: started,
          isCard: false,
        );
        return;
      }

      // Manual — bank transfer or non-aggregator Mobile Money.
      if (_referenceController.text.trim().isEmpty) {
        setState(() {
          _error = 'Enter the reference/transaction ID for your payment.';
          _submitting = false;
        });
        return;
      }

      final message = await widget.service.submitManualPayment(
        widget.plan.id,
        _selectedGateway.id,
        _referenceController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      widget.onDone();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not start the payment. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Checkout — ${widget.plan.name}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Total: ${widget.plan.formattedPrice()}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
            // Flutter 3.32+ manages radio state from the RadioGroup ancestor.
            RadioGroup<PaymentGatewayInfo>(
              groupValue: _selectedGateway,
              onChanged: (value) {
                if (_submitting || value == null) return;
                setState(() => _selectedGateway = value);
              },
              child: Column(
                children: widget.gateways.map((g) => RadioListTile<PaymentGatewayInfo>(
                      value: g,
                      title: Text(g.type == 'card' ? 'Visa / MasterCard' : g.name),
                    )).toList(),
              ),
            ),
            if (_selectedGateway.collectsAutomatically) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _network,
                decoration: const InputDecoration(labelText: 'Network'),
                items: [
                  if (_selectedGateway.supportsMtn) const DropdownMenuItem(value: 'mtn', child: Text('MTN Mobile Money')),
                  if (_selectedGateway.supportsAirtel) const DropdownMenuItem(value: 'airtel', child: Text('Airtel Money')),
                ],
                onChanged: (value) => setState(() => _network = value ?? 'mtn'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', hintText: 'e.g. 0700000000'),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "You'll approve this on your phone. We will never ask for your Mobile Money PIN here.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ] else if (_selectedGateway.type != 'card') ...[
              // Manual — bank transfer, or a mobile_money gateway with
              // no aggregator API configured. Show where to actually
              // send the money, then collect the user's own reference
              // for admin verification, matching the web app's flow.
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blueGrey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedGateway.type == 'bank' ? 'Bank Transfer Details' : 'Mobile Money Details',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    if (_selectedGateway.type == 'bank') ...[
                      if (_selectedGateway.bankName != null) Text('Bank: ${_selectedGateway.bankName}', style: const TextStyle(fontSize: 13)),
                      if (_selectedGateway.accountName != null) Text('Account Name: ${_selectedGateway.accountName}', style: const TextStyle(fontSize: 13)),
                      if (_selectedGateway.accountNumber != null) Text('Account Number: ${_selectedGateway.accountNumber}', style: const TextStyle(fontSize: 13)),
                      if (_selectedGateway.routingOrSwift != null) Text('Routing/SWIFT: ${_selectedGateway.routingOrSwift}', style: const TextStyle(fontSize: 13)),
                    ] else ...[
                      if (_selectedGateway.providerName != null) Text('Provider: ${_selectedGateway.providerName}', style: const TextStyle(fontSize: 13)),
                      if (_selectedGateway.merchantNumber != null) Text('Send to: ${_selectedGateway.merchantNumber}', style: const TextStyle(fontSize: 13)),
                    ],
                    if (_selectedGateway.instructions != null) ...[
                      const SizedBox(height: 6),
                      Text(_selectedGateway.instructions!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(labelText: 'Payment Reference / Transaction ID', hintText: 'e.g. the SMS confirmation code'),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Send the payment above first, then submit your reference here — an admin will verify it and activate your plan.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _pay,
              child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Pay'),
            ),
          ],
        ),
      ),
    );
  }
}


class _IoTecPaymentConfirmationDialog extends StatefulWidget {
  final SubscriptionService service;
  final int transactionId;
  final bool isCard;
  final String initialMessage;
  final VoidCallback onConfirmed;

  const _IoTecPaymentConfirmationDialog({
    required this.service,
    required this.transactionId,
    required this.isCard,
    required this.initialMessage,
    required this.onConfirmed,
  });

  @override
  State<_IoTecPaymentConfirmationDialog> createState() =>
      _IoTecPaymentConfirmationDialogState();
}

class _IoTecPaymentConfirmationDialogState
    extends State<_IoTecPaymentConfirmationDialog> {
  IoTecPaymentStatus? _status;
  String? _error;
  bool _checking = true;
  bool _closed = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  Future<void> _poll() async {
    while (!_closed && mounted && _attempts < 75) {
      _attempts++;

      try {
        final status = await widget.service.ioTecPaymentStatus(
          widget.transactionId,
        );

        if (!mounted || _closed) return;

        setState(() {
          _status = status;
          _error = null;
          _checking = status.isPending;
        });

        if (status.isSuccessful) {
          widget.onConfirmed();
          return;
        }

        if (status.isFinalFailure) {
          return;
        }
      } on ApiException catch (e) {
        if (!mounted || _closed) return;
        setState(() {
          _error = e.message;
          _checking = true;
        });
      } catch (_) {
        if (!mounted || _closed) return;
        setState(() {
          _error = 'We are still waiting for payment confirmation.';
          _checking = true;
        });
      }

      await Future<void>.delayed(const Duration(seconds: 4));
    }

    if (mounted && !_closed && (_status?.isPending ?? true)) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final successful = _status?.isSuccessful == true;
    final failed = _status?.isFinalFailure == true;
    final pending = !successful && !failed;

    final icon = successful
        ? Icons.check_circle_rounded
        : failed
            ? Icons.error_rounded
            : widget.isCard
                ? Icons.credit_card_rounded
                : Icons.phone_android_rounded;

    final iconColor = successful
        ? Colors.green
        : failed
            ? Colors.red
            : const Color(0xFF00897B);

    final title = successful
        ? 'Payment successful'
        : failed
            ? 'Payment not completed'
            : widget.isCard
                ? 'Complete card payment'
                : 'Payment request sent';

    final message = successful
        ? 'Your payment has been confirmed and your subscription is now active.'
        : failed
            ? (_status?.statusMessage ??
                'The payment could not be completed. Please try again.')
            : widget.isCard
                ? 'Complete the Visa / MasterCard payment in the secure ioTec browser page, then return here. We will confirm it automatically.'
                : (widget.initialMessage.trim().isNotEmpty
                    ? widget.initialMessage
                    : 'Approve the Mobile Money prompt on your phone. We will confirm it automatically.');

    return PopScope(
      canPop: !successful && !failed,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text(
                    'Transaction',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const Spacer(),
                  Text(
                    '#${widget.transactionId}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (pending)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_checking)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.schedule_rounded, size: 19),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _checking
                          ? 'Waiting for confirmation'
                          : 'Still pending — you can check again later',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            if (_error != null && pending) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (pending)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                if (pending) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: successful
                        ? () => Navigator.of(context).pop()
                        : failed
                            ? () => Navigator.of(context).pop()
                            : _checking
                                ? null
                                : () {
                                    setState(() {
                                      _checking = true;
                                      _attempts = 0;
                                    });
                                    _poll();
                                  },
                    child: Text(
                      successful
                          ? 'Continue'
                          : failed
                              ? 'Close'
                              : 'Check again',
                    ),
                  ),
                ),
              ],
            ),
            if (!widget.isCard && pending) ...[
              const SizedBox(height: 12),
              const Text(
                'Never enter your Mobile Money PIN in My Digital Diary. Approve only from your phone prompt.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingPaymentSheet extends StatefulWidget {
  final PaymentRecord payment;
  final List<PaymentGatewayInfo> gateways;
  final SubscriptionService service;
  final String? accountPhone;
  final VoidCallback onDone;

  const _PendingPaymentSheet({
    required this.payment,
    required this.gateways,
    required this.service,
    this.accountPhone,
    required this.onDone,
  });

  @override
  State<_PendingPaymentSheet> createState() => _PendingPaymentSheetState();
}

class _PendingPaymentSheetState extends State<_PendingPaymentSheet> {
  PaymentGatewayInfo? _selectedGateway;
  late final TextEditingController _phoneController;
  final _referenceController = TextEditingController();
  String _network = 'mtn';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedGateway = widget.gateways.first;
    _phoneController = TextEditingController(text: widget.accountPhone ?? '');
    if (widget.payment.network == 'airtel') _network = 'airtel';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final gateway = _selectedGateway;
    if (gateway == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      late final String message;

      if (gateway.collectsAutomatically) {
        final phone = _phoneController.text.trim();
        if (phone.isEmpty) {
          setState(() {
            _error = 'Enter the phone number that should receive the Mobile Money prompt.';
            _submitting = false;
          });
          return;
        }

        message = await widget.service.retryPendingMobileMoney(
          widget.payment.id,
          phone,
          _network,
        );
      } else if (gateway.type == 'bank') {
        final reference = _referenceController.text.trim();
        if (reference.isEmpty) {
          setState(() {
            _error = 'Enter the bank transaction/reference number after making the transfer.';
            _submitting = false;
          });
          return;
        }

        message = await widget.service.submitPendingBankPayment(
          widget.payment.id,
          gateway.id,
          reference,
        );
      } else {
        setState(() {
          _error = 'This payment method cannot be used for a pending invoice.';
          _submitting = false;
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      widget.onDone();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateway = _selectedGateway!;
    final isMobileMoney = gateway.collectsAutomatically;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Complete pending payment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${widget.payment.plan ?? 'Subscription'} · ${widget.payment.currency} ${widget.payment.amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PaymentGatewayInfo>(
              initialValue: gateway,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: widget.gateways
                  .map(
                    (g) => DropdownMenuItem(
                      value: g,
                      child: Text(g.collectsAutomatically ? '${g.name} prompt' : g.name),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _selectedGateway = value),
            ),
            const SizedBox(height: 12),
            if (isMobileMoney) ...[
              DropdownButtonFormField<String>(
                initialValue: _network,
                decoration: const InputDecoration(labelText: 'Network'),
                items: [
                  if (gateway.supportsMtn)
                    const DropdownMenuItem(value: 'mtn', child: Text('MTN Mobile Money')),
                  if (gateway.supportsAirtel)
                    const DropdownMenuItem(value: 'airtel', child: Text('Airtel Money')),
                ],
                onChanged: (value) => setState(() => _network = value ?? 'mtn'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '0700000000',
                  helperText: 'A payment prompt will be sent to this number.',
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bank Transfer Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (gateway.bankName != null) Text('Bank: ${gateway.bankName}'),
                    if (gateway.accountName != null) Text('Account Name: ${gateway.accountName}'),
                    if (gateway.accountNumber != null) Text('Account Number: ${gateway.accountNumber}'),
                    if (gateway.routingOrSwift != null) Text('Routing/SWIFT: ${gateway.routingOrSwift}'),
                    if (gateway.instructions != null) ...[
                      const SizedBox(height: 6),
                      Text(gateway.instructions!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Bank transaction reference',
                  hintText: 'Enter the transaction/reference number',
                  helperText: 'Transfer the invoice amount first, then submit the reference.',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isMobileMoney ? Icons.mobile_friendly : Icons.account_balance),
              label: Text(isMobileMoney ? 'Send payment prompt' : 'Submit bank payment'),
            ),
          ],
        ),
      ),
    );
  }
}

