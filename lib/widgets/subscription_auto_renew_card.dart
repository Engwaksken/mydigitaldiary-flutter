import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/subscription_auto_renew_service.dart';

class SubscriptionAutoRenewCard extends StatefulWidget {
  final String? fallbackPhone;
  final VoidCallback? onChanged;

  const SubscriptionAutoRenewCard({
    super.key,
    this.fallbackPhone,
    this.onChanged,
  });

  @override
  State<SubscriptionAutoRenewCard> createState() =>
      _SubscriptionAutoRenewCardState();
}

class _SubscriptionAutoRenewCardState extends State<SubscriptionAutoRenewCard> {
  final _service = SubscriptionAutoRenewService();

  SubscriptionAutoRenewInfo? _info;
  TextEditingController? _phoneController;

  bool _loading = true;
  bool _saving = false;
  String _network = 'mtn';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final info = await _service.getSettings();

      if (!mounted) return;

      _phoneController?.dispose();
      _phoneController = TextEditingController(
        text: info.phoneNumber ?? widget.fallbackPhone ?? '',
      );

      setState(() {
        _info = info;
        _network = _normaliseNetwork(info);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  String _normaliseNetwork(
    SubscriptionAutoRenewInfo info,
  ) {
    var network = info.network;

    if (network == 'mtn' && !info.supportsMtn && info.supportsAirtel) {
      network = 'airtel';
    }

    if (network == 'airtel' && !info.supportsAirtel && info.supportsMtn) {
      network = 'mtn';
    }

    return network;
  }

  Future<void> _enable() async {
    final phone = _phoneController?.text.trim() ?? '';

    if (phone.isEmpty) {
      setState(() {
        _error = 'Enter the Mobile Money number for renewal prompts.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final message = await _service.enable(
        phoneNumber: phone,
        network: _network,
      );

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      widget.onChanged?.call();
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  Future<void> _disable() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Turn off Auto Renewal?'),
            content: const Text(
              'Your current subscription stays active until its expiry date, '
              'but My Digital Diary will not automatically start the next '
              'renewal payment.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep On'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Turn Off'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final message = await _service.disable();

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      widget.onChanged?.call();
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text('Loading Auto Renewal...'),
            ],
          ),
        ),
      );
    }

    final info = _info;

    if (info == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error ?? 'Could not load Auto Renewal settings.',
          ),
        ),
      );
    }

    if (!info.available && !info.enabled) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.autorenew_rounded,
                color: Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto Renewal',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.message ??
                          'Auto Renewal is not available for this subscription.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final enabled = info.enabled;
    final phoneController = _phoneController ??= TextEditingController(
      text: widget.fallbackPhone ?? '',
    );

    return Card(
      color: enabled ? const Color(0xFFECFDF5) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: enabled
                        ? const Color(0xFFD1FAE5)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.autorenew_rounded,
                    color: enabled
                        ? const Color(0xFF047857)
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Auto Renewal',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: enabled
                                  ? const Color(
                                      0xFFD1FAE5,
                                    )
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(
                                999,
                              ),
                            ),
                            child: Text(
                              enabled ? 'ON' : 'OFF',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: enabled
                                    ? const Color(
                                        0xFF047857,
                                      )
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Automatically start your next renewal payment on the subscription expiry date.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (enabled) ...[
              _InfoRow(
                label: 'Next renewal',
                value: info.nextRenewalDate ?? '—',
              ),
              _InfoRow(
                label: 'Payment method',
                value: info.gatewayName ?? 'Mobile Money',
              ),
              _InfoRow(
                label: 'Network',
                value: _network.toUpperCase(),
              ),
              _InfoRow(
                label: 'Renewal phone',
                value: info.phoneNumber ?? widget.fallbackPhone ?? '—',
              ),
              const SizedBox(height: 8),
              const Text(
                'You will approve the Mobile Money prompt on your phone. '
                'My Digital Diary never stores your Mobile Money PIN.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _disable,
                icon: const Icon(
                  Icons.toggle_off_outlined,
                ),
                label: const Text(
                  'Turn Off Auto Renewal',
                ),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: _network,
                decoration: const InputDecoration(
                  labelText: 'Mobile Money network',
                ),
                items: [
                  if (info.supportsMtn)
                    const DropdownMenuItem(
                      value: 'mtn',
                      child: Text('MTN Mobile Money'),
                    ),
                  if (info.supportsAirtel)
                    const DropdownMenuItem(
                      value: 'airtel',
                      child: Text('Airtel Money'),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _network = value;
                        });
                      },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Renewal phone number',
                  hintText: 'e.g. 0700000000',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'On your expiry date, a Mobile Money payment prompt will be sent to this number. '
                'Your subscription renews only after payment succeeds.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _enable,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.toggle_on_outlined,
                      ),
                label: Text(
                  _saving ? 'Saving...' : 'Enable Auto Renewal',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
