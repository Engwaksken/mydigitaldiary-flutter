import 'package:flutter/material.dart';

import '../services/biometric_login_service.dart';

class BiometricLoginButton extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> user) onAuthenticated;

  const BiometricLoginButton({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<BiometricLoginButton> createState() => _BiometricLoginButtonState();
}

class _BiometricLoginButtonState extends State<BiometricLoginButton> {
  BiometricLoginState? _state;
  bool _loading = true;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final state = await BiometricLoginService.instance.state();

    if (!mounted) {
      return;
    }

    setState(() {
      _state = state;
      _loading = false;
    });
  }

  Future<void> _login() async {
    if (_authenticating) {
      return;
    }

    setState(() => _authenticating = true);

    try {
      final user =
          await BiometricLoginService.instance.authenticateAndRestoreSession();

      if (!mounted) {
        return;
      }

      await widget.onAuthenticated(user);
    } on BiometricLoginException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );

      await _refresh();
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _state?.canOfferLogin != true) {
      return const SizedBox.shrink();
    }

    final account = _state?.accountLabel?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'or',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _authenticating ? null : _login,
          icon: _authenticating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fingerprint_rounded),
          label: Text(
            _authenticating
                ? 'Checking fingerprint...'
                : account != null && account.isNotEmpty
                    ? 'Use Fingerprint · $account'
                    : 'Use Fingerprint to Login',
          ),
        ),
      ],
    );
  }
}
