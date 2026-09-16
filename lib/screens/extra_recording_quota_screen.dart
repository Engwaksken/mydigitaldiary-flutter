import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/extra_request.dart';
import '../services/api_client.dart';
import '../services/extra_request_service.dart';
import '../services/subscription_service.dart';

class ExtraRecordingQuotaScreen extends StatefulWidget {
  const ExtraRecordingQuotaScreen({super.key});

  @override
  State<ExtraRecordingQuotaScreen> createState() =>
      _ExtraRecordingQuotaScreenState();
}

class _ExtraRecordingQuotaScreenState extends State<ExtraRecordingQuotaScreen> {
  final _service = ExtraRequestService();
  List<ExtraRequest> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final requests = await _service.list();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<ExtraRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateRequestSheet(service: _service),
    );

    if (created == null) {
      await _load();
      return;
    }

    await _openPaySheet(created);
  }

  Future<void> _openPaySheet(ExtraRequest request) async {
    final settled = await showModalBottomSheet<ExtraRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PayRequestSheet(
        request: request,
        service: _service,
      ),
    );

    if (!mounted) return;

    if (settled != null && settled.isApplied) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Payment successful. ${settled.quotaAmount} extra recording '
          'minutes are now on your account.',
        ),
      ));
    }

    await _load();
  }

  bool _hasPending() => _requests.any((r) => r.isPending);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extra Recording Quota')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buy minutes'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.av_timer_rounded,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Run out of transcription minutes? Buy extra '
                              'recording quota in packages of 10–1000 minutes. '
                              'Each package applies to your account for 30 days.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ),
                  if (_hasPending())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Pending requests below still need payment to be '
                        'applied.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  if (_requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                            'No extra recording quota requests yet.\n'
                            'Tap "Buy minutes" to get started.'),
                      ),
                    )
                  else
                    ..._requests.map(_buildRequestCard),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildRequestCard(ExtraRequest request) {
    final (label, color) = _statusStyle(request);
    final expired = request.isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (expired)
                  const Text(
                    'EXPIRED',
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${request.quotaAmount} minutes',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              request.formattedAmount,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (request.description != null) ...[
              const SizedBox(height: 4),
              Text(request.description!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            if (request.isApplied) ...[
              const Divider(height: 12),
              Text(
                'Applied ${request.appliedAt?.toLocal().toString().substring(0, 16) ?? ''}',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              Text(
                request.expiresAt == null
                    ? 'No expiry'
                    : 'Expires ${request.expiresAt!.toLocal().toString().substring(0, 10)}',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
            if (request.isPending) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _openPaySheet(request),
                  icon: const Icon(Icons.lock_open_rounded, size: 16),
                  label: const Text('Pay now'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, Color) _statusStyle(ExtraRequest request) {
    final status = request.status;
    return switch (status) {
      'applied' => ('APPLIED', Colors.green.shade700),
      'approved' => ('APPROVED', Colors.blue.shade700),
      'rejected' || 'failed' || 'cancelled' || 'canceled' =>
        (status.toUpperCase(), Colors.red.shade700),
      _ => ('PENDING', Colors.orange.shade800),
    };
  }
}

class _CreateRequestSheet extends StatefulWidget {
  final ExtraRequestService service;

  const _CreateRequestSheet({required this.service});

  @override
  State<_CreateRequestSheet> createState() => _CreateRequestSheetState();
}

class _CreateRequestSheetState extends State<_CreateRequestSheet> {
  double _minutes = 60;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 0) {
      setState(() => _error = 'Enter a valid amount in your currency.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final created = await widget.service.create(
        quotaAmount: _minutes.round(),
        amount: amount,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Buy extra recording minutes',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Packages run from 10 to 1000 minutes and apply for 30 '
                'days.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                'Minutes: ${_minutes.round()}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _minutes,
                min: 10,
                max: 1000,
                divisions: 99,
                label: '${_minutes.round()}',
                onChanged: (value) => setState(() => _minutes = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                enabled: !_submitting,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: 'e.g. 60000',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                enabled: !_submitting,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_submitting
                    ? 'Creating request...'
                    : 'Create request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayRequestSheet extends StatefulWidget {
  final ExtraRequest request;
  final ExtraRequestService service;

  const _PayRequestSheet({required this.request, required this.service});

  @override
  State<_PayRequestSheet> createState() => _PayRequestSheetState();
}

class _PayRequestSheetState extends State<_PayRequestSheet> {
  final _phoneController = TextEditingController();

  bool _mobileMoney = true;
  IoTecGatewayOptions? _options;
  bool _submitting = false;
  String? _error;

  bool get _supportsMobileMoney =>
      _options?.supportsMobileMoney ?? true;
  bool get _supportsCard => _options?.supportsCard ?? true;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final service = SubscriptionService();
      final options = await service.ioTecOptions();
      if (!mounted) return;
      setState(() {
        _options = options;
        if (!options.supportsMobileMoney && options.supportsCard) {
          _mobileMoney = false;
        }
      });
    } catch (_) {
      return;
    }
  }

  Future<bool> _openExternalUrl(Uri uri) async {
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (_mobileMoney && _phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your Mobile Money number.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await widget.service.pay(
        widget.request.id,
        paymentChannel: _mobileMoney ? 'mobile_money' : 'card',
        payer: _mobileMoney ? _phoneController.text : '',
      );

      final cardUrl = result.cardRedirectUrl;

      if (!_mobileMoney) {
        if (cardUrl == null || cardUrl.isEmpty) {
          throw Exception(
              'ioTec did not return a secure card checkout URL.');
        }

        final opened = await _openExternalUrl(Uri.parse(cardUrl));
        if (!opened) throw Exception('Could not open the card checkout.');

        if (!mounted) return;
        setState(() => _submitting = false);

        final confirmed = await _showCardReturnPrompt();
        if (!confirmed || !mounted) return;
      }

      final settled = await widget.service.waitForSettled(
        widget.request.id,
        timeout: const Duration(minutes: 3),
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      if (settled.isApplied) {
        Navigator.of(context).pop(settled);
        return;
      }

      if (settled.isTerminalFailure) {
        setState(() => _error =
            settled.iotecTransaction?.statusMessage ??
                'The payment was not successful.');
        return;
      }

      setState(() => _error =
          'Payment is still pending. You can check again shortly.');
    } on ApiException catch (e) {
      setState(() => _submitting = false);
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<bool> _showCardReturnPrompt() async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Complete card payment'),
            content: const Text(
              'Complete the card payment in the secure browser, then '
              'confirm here so we can check the status.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('I have paid'),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pay for extra quota',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.request.quotaAmount} minutes · '
                '${widget.request.formattedAmount}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Mobile Money'),
                    avatar: const Icon(Icons.phone_android_rounded, size: 18),
                    selected: _mobileMoney,
                    onSelected: _submitting || !_supportsMobileMoney
                        ? null
                        : (value) => setState(() => _mobileMoney = value),
                  ),
                  ChoiceChip(
                    label: const Text('Visa / MasterCard'),
                    avatar: const Icon(Icons.credit_card_rounded, size: 18),
                    selected: !_mobileMoney,
                    onSelected: _submitting || !_supportsCard
                        ? null
                        : (value) => setState(() => _mobileMoney = !value),
                  ),
                ],
              ),
              if (_mobileMoney) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Money number',
                    hintText: '2567XXXXXXXX',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _mobileMoney
                            ? Icons.lock_outline_rounded
                            : Icons.open_in_browser_rounded,
                      ),
                label: Text(
                  _submitting
                      ? 'Please wait...'
                      : _mobileMoney
                          ? 'Pay with Mobile Money'
                          : 'Continue to secure checkout',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}