import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

/// Mirrors resources/views/auth/verify-otp.blade.php's flow exactly — a
/// 6-digit code emailed after the password check, entered here to
/// actually complete login.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _status;

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().verifyOtp(_codeController.text.trim());
      // AuthGate switches to DashboardScreen automatically once
      // status flips to loggedIn.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _status = null;
    });
    try {
      await context.read<AuthService>().resendOtp();
      setState(() => _status = 'A new code has been sent to your email.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: AppLogo(size: 78),
                ),
                const SizedBox(height: 20),
                Text(
                  "We've emailed a 6-digit verification code to your address. Enter it below to finish signing in. The code expires in 10 minutes.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                if (_status != null) ...[
                  Text(_status!,
                      style: const TextStyle(color: Color(0xFF059669))),
                  const SizedBox(height: 8),
                ],
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!,
                        style: const TextStyle(color: Color(0xFFB91C1C))),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, letterSpacing: 12),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    labelText: '6-digit code',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _loading ? null : _resend,
                        child: const Text('Resend code'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Verify & Sign In'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
