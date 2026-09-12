import 'package:flutter/material.dart';

import '../services/biometric_login_service.dart';

class BiometricSettingsCard extends StatefulWidget {
  final String? accountLabel;

  const BiometricSettingsCard({
    super.key,
    this.accountLabel,
  });

  @override
  State<BiometricSettingsCard> createState() =>
      _BiometricSettingsCardState();
}

class _BiometricSettingsCardState extends State<BiometricSettingsCard> {
  BiometricLoginState? _state;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await BiometricLoginService.instance.state();

    if (!mounted) {
      return;
    }

    setState(() {
      _state = state;
      _loading = false;
    });
  }

  Future<void> _enable() async {
    setState(() => _saving = true);

    try {
      await BiometricLoginService.instance.enableForCurrentAccount(
        accountLabel: widget.accountLabel,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fingerprint login has been enabled on this device.',
          ),
        ),
      );

      await _load();
    } on BiometricLoginException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _disable() async {
    setState(() => _saving = true);

    await BiometricLoginService.instance.disable();

    if (!mounted) {
      return;
    }

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fingerprint login has been removed from this device.'),
      ),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.fingerprint_rounded),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fingerprint Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use a fingerprint already registered in your phone settings as an alternative way to sign in to My Digital Diary.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (state?.deviceSupported != true)
                    const Text(
                      'Fingerprint authentication is not supported on this device.',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (state?.fingerprintEnrolled != true)
                    const Text(
                      'No fingerprint is registered on this phone. Add one in the phone security settings first.',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (state?.hasRememberedSession != true)
                    const Text(
                      'Sign in with Remember Me enabled first so this device can securely restore your account after fingerprint verification.',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: state?.enabled == true
                        ? OutlinedButton.icon(
                            onPressed: _saving ? null : _disable,
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: Text(
                              _saving
                                  ? 'Updating...'
                                  : 'Remove Fingerprint Login',
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: _saving ||
                                    state?.deviceSupported != true ||
                                    state?.fingerprintEnrolled != true ||
                                    state?.hasRememberedSession != true
                                ? null
                                : _enable,
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: Text(
                              _saving
                                  ? 'Registering...'
                                  : 'Register Fingerprint',
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'My Digital Diary does not receive or store your fingerprint. Your phone verifies it securely and only returns whether authentication succeeded.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
