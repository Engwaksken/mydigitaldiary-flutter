import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _checkingConnection = false;
  bool _hasConnectionIssue = false;

  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();

    /*
     * Do not automatically show Retry just because authentication is
     * taking a few seconds.
     *
     * After a short delay, check whether the phone actually has internet.
     * Retry UI is shown ONLY when this connectivity test fails.
     */
    _connectionTimer = Timer(
      const Duration(seconds: 3),
      _checkInternetConnection,
    );
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    super.dispose();
  }

  Future<bool> _hasInternetConnection() async {
    try {
      /*
       * A DNS lookup gives us a lightweight indication that the device
       * currently has usable internet access.
       */
      final result = await InternetAddress.lookup(
        'cloudflare.com',
      ).timeout(
        const Duration(seconds: 5),
      );

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkInternetConnection() async {
    if (_checkingConnection) return;

    _checkingConnection = true;

    final connected = await _hasInternetConnection();

    _checkingConnection = false;

    if (!mounted) return;

    setState(() {
      _hasConnectionIssue = !connected;
    });
  }

  Future<void> _retry() async {
    if (_checkingConnection) return;

    setState(() {
      _checkingConnection = true;
      _hasConnectionIssue = false;
    });

    final connected = await _hasInternetConnection();

    if (!mounted) return;

    if (!connected) {
      setState(() {
        _checkingConnection = false;
        _hasConnectionIssue = true;
      });

      return;
    }

    setState(() {
      _checkingConnection = false;
      _hasConnectionIssue = false;
    });

    /*
     * Internet is available again.
     * Retry authentication/session bootstrap.
     */
    await context.read<AuthService>().bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /*
                       * Logo
                       */
                      Container(
                        width: 170,
                        height: 170,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: 0.90,
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.16,
                              ),
                              blurRadius: 28,
                              offset: const Offset(
                                0,
                                10,
                              ),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icon/logo.png',
                            width: 134,
                            height: 134,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) {
                              return Center(
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color: primaryColor,
                                  size: 76,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      /*
                       * Tagline
                       */
                      Text(
                        'Plan your day. Manage your money.\n'
                        'Track your progress in one place.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: 0.96,
                          ),
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 30),

                      /*
                       * Normal splash loading indicator.
                       *
                       * This stays visible while the application checks
                       * the user's saved authentication/session state.
                       */
                      if (!_hasConnectionIssue)
                        const SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),

                      /*
                       * Connectivity warning.
                       *
                       * IMPORTANT:
                       * This is NOT displayed because the splash has
                       * taken too long.
                       *
                       * It is shown only after the actual internet test
                       * above reports that connectivity is unavailable.
                       */
                      if (_hasConnectionIssue) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No internet connection',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 310,
                          ),
                          child: Text(
                            'Check your mobile data or Wi-Fi '
                            'connection, then try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: 0.85,
                              ),
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _checkingConnection ? null : _retry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primaryColor,
                              disabledBackgroundColor: Colors.white.withValues(
                                alpha: 0.75,
                              ),
                              disabledForegroundColor: primaryColor.withValues(
                                alpha: 0.65,
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  14,
                                ),
                              ),
                            ),
                            icon: _checkingConnection
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primaryColor,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    size: 20,
                                  ),
                            label: Text(
                              _checkingConnection ? 'Checking...' : 'Retry Now',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
