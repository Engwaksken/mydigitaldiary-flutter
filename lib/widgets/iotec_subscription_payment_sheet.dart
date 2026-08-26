import 'package:flutter/material.dart';

import '../services/iotec_subscription_service.dart';

enum IoTecPaymentMethod {
  mobileMoney,
  card,
}

class IoTecSubscriptionPaymentSheet extends StatefulWidget {
  final IoTecSubscriptionService service;
  final int planId;

  /// The parent app should implement this using its existing external URL
  /// launcher/deep-link helper. Return true when the URL was opened.
  final Future<bool> Function(Uri uri) openExternalUrl;

  /// Called after Laravel confirms subscription activation.
  final Future<void> Function()? onActivated;

  const IoTecSubscriptionPaymentSheet({
    super.key,
    required this.service,
    required this.planId,
    required this.openExternalUrl,
    this.onActivated,
  });

  @override
  State<IoTecSubscriptionPaymentSheet> createState() =>
      _IoTecSubscriptionPaymentSheetState();
}

class _IoTecSubscriptionPaymentSheetState
    extends State<IoTecSubscriptionPaymentSheet> {
  final _phoneController = TextEditingController();

  IoTecGatewayOptions? _options;
  IoTecPaymentMethod _method = IoTecPaymentMethod.mobileMoney;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  int? _pendingTransactionId;

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
      final value = await widget.service.options();

      if (!mounted) return;

      setState(() {
        _options = value;
        _loading = false;

        if (!value.supportsMobileMoney && value.supportsCard) {
          _method = IoTecPaymentMethod.card;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load ioTec payment options.';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final options = _options;
    if (options == null || !options.enabled) {
      setState(() {
        _error = 'ioTec payments are currently unavailable.';
      });
      return;
    }

    if (_method == IoTecPaymentMethod.mobileMoney &&
        _phoneController.text.trim().isEmpty) {
      setState(() {
        _error = 'Enter your Mobile Money number.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final start = _method == IoTecPaymentMethod.card
          ? await widget.service.startCard(planId: widget.planId)
          : await widget.service.startMobileMoney(
              planId: widget.planId,
              phone: _phoneController.text,
            );

      if (!start.success || start.transactionId == null) {
        throw Exception(
          start.message.isEmpty
              ? 'Could not start payment.'
              : start.message,
        );
      }

      _pendingTransactionId = start.transactionId;

      if (_method == IoTecPaymentMethod.card) {
        final url = start.redirectUrl;

        if (url == null || url.isEmpty) {
          throw Exception(
            'ioTec did not return a Visa / MasterCard checkout URL.',
          );
        }

        final opened = await widget.openExternalUrl(Uri.parse(url));

        if (!opened) {
          throw Exception('Could not open the secure card checkout.');
        }

        if (!mounted) return;

        setState(() {
          _submitting = false;
        });

        await _showCardReturnDialog();
        return;
      }

      final result = await widget.service.waitForFinalStatus(
        start.transactionId!,
      );

      await _handleFinalResult(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showCardReturnDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Complete card payment'),
          content: const Text(
            'Complete the Visa / MasterCard payment in the secure browser. '
            'When you return here, tap Check payment status.',
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _checkPendingTransaction();
              },
              child: const Text('Check payment status'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkPendingTransaction() async {
    final transactionId = _pendingTransactionId;
    if (transactionId == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await widget.service.waitForFinalStatus(
        transactionId,
        timeout: const Duration(minutes: 1),
      );

      await _handleFinalResult(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _error = 'Could not confirm the payment yet. Try again shortly.';
      });
    }
  }

  Future<void> _handleFinalResult(
    IoTecPaymentStatus result,
  ) async {
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _submitting = false;
      });

      if (widget.onActivated != null) {
        await widget.onActivated!();
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment successful. Your subscription is now active.',
          ),
        ),
      );

      return;
    }

    if (result.isFinalFailure) {
      setState(() {
        _submitting = false;
        _error = result.statusMessage ??
            'The payment was not successful.';
      });

      return;
    }

    setState(() {
      _submitting = false;
      _error =
          'Payment is still pending. You can check the status again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pay with ioTec',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose Mobile Money or Visa / MasterCard. '
                      'Your subscription activates automatically after '
                      'ioTec confirms payment.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 20),

                    RadioGroup<IoTecPaymentMethod>(
                      groupValue: _method,
                      onChanged: (value) {
                        if (_submitting || value == null) return;
                        setState(() => _method = value);
                      },
                      child: Column(
                        children: [
                          if (options?.supportsMobileMoney == true)
                            const RadioListTile<IoTecPaymentMethod>(
                              contentPadding: EdgeInsets.zero,
                              value: IoTecPaymentMethod.mobileMoney,
                              title: Text(
                                'Mobile Money',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Approve the ioTec payment prompt on your phone.',
                              ),
                              secondary: Icon(
                                Icons.phone_android_rounded,
                              ),
                            ),
                          if (options?.supportsCard == true)
                            const RadioListTile<IoTecPaymentMethod>(
                              contentPadding: EdgeInsets.zero,
                              value: IoTecPaymentMethod.card,
                              title: Text(
                                'Visa / MasterCard',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Continue to ioTec secure hosted card checkout.',
                              ),
                              secondary: Icon(
                                Icons.credit_card_rounded,
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (_method == IoTecPaymentMethod.mobileMoney &&
                        options?.supportsMobileMoney == true) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Money number',
                          hintText: '2567XXXXXXXX',
                          prefixIcon:
                              Icon(Icons.phone_android_rounded),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _method == IoTecPaymentMethod.card
                                  ? Icons.open_in_browser_rounded
                                  : Icons.lock_outline_rounded,
                            ),
                      label: Text(
                        _submitting
                            ? 'Please wait...'
                            : _method == IoTecPaymentMethod.card
                                ? 'Continue to secure checkout'
                                : 'Pay with Mobile Money',
                      ),
                    ),

                    if (_pendingTransactionId != null &&
                        !_submitting) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _checkPendingTransaction,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Check payment status'),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
