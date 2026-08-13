import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/branding_service.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  BrandingInfo? _branding;
  bool _showRetry = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    BrandingService().fetch().then((branding) {
      if (mounted) setState(() => _branding = branding);
    });
    // If bootstrap() hasn't resolved to a different screen within a
    // few seconds, something's stuck (most likely: a token exists but
    // /me has never once succeeded while online, and there's no
    // connection right now to try) — show a way out instead of
    // leaving the user staring at a spinner indefinitely.
    _retryTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showRetry = true);
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon/logo.png',
                  height: 88,
                  errorBuilder: (_, __, ___) => const Icon(Icons.show_chart_rounded, color: AppColors.forest, size: 64),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              _branding?.siteName ?? 'My Digital Diary',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.forest),
            if (_showRetry) ...[
              const SizedBox(height: 24),
              const Text(
                "Still checking your session. You can retry if your connection is weak.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.read<AuthService>().bootstrap(),
                child: const Text('Retry Now', style: TextStyle(color: AppColors.forest)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
