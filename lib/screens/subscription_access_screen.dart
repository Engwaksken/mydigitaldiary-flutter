import 'package:flutter/material.dart';

import '../services/organization_access_service.dart';
import '../widgets/managed_subscription_banner.dart';
import 'subscription_screen.dart';

class SubscriptionAccessScreen extends StatefulWidget {
  const SubscriptionAccessScreen({super.key});

  @override
  State<SubscriptionAccessScreen> createState() =>
      _SubscriptionAccessScreenState();
}

class _SubscriptionAccessScreenState
    extends State<SubscriptionAccessScreen> {
  final OrganizationAccessService _service =
      OrganizationAccessService();

  OrganizationAccessContext? _contextData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.context();

      if (!mounted) return;

      setState(() {
        _contextData = data;
        _loading = false;
      });

      if (!data.managedByOwner) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const SubscriptionScreen(),
            ),
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _contextData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : data == null
              ? const Center(
                  child: Text(
                    'Could not load subscription access.',
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ManagedSubscriptionBanner(
                    contextData: data,
                  ),
                ),
    );
  }
}
