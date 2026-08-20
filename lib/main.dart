import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/branding_service.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/connectivity_gate.dart';

Color _colorFromHex(String hex) {
  var value = hex.replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never make users wait on network-dependent startup services before the
  // first Flutter frame. Branding, Firebase and notification registration are
  // useful, but none of them are required to show Login/Home immediately.
  unawaited(BrandingService().fetch());

  runApp(const PersonalMonitorApp());

  // Start secondary services after Flutter has already drawn the app. Weak or
  // unavailable internet therefore cannot hold the user on a native/splash
  // screen. Each initializer is isolated so one failure cannot block another.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeBackgroundServices());
  });
}

Future<void> _initializeBackgroundServices() async {
  try {
    await NotificationService.instance
        .initializeLocalNotifications()
        .timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Local notifications could not be initialized: $e');
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(const Duration(seconds: 4));
    unawaited(NotificationService.instance.initializePushNotifications());
  } catch (e) {
    debugPrint('Firebase push notifications not configured/reachable yet: $e');
  }
}

class PersonalMonitorApp extends StatelessWidget {
  const PersonalMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService()..bootstrap(),
      // Consumer (not context.watch directly in this build method) —
      // AuthService isn't actually available on THIS context until
      // inside the provider's own subtree, which Consumer's builder
      // callback runs within.
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          final user = auth.user;
          // Defensive: a malformed color, an unrecognized font name
          // failing later during actual text rendering (google_fonts
          // isn't fully verified in this sandbox — see app_theme.dart),
          // or anything else going wrong while building a custom
          // theme falls back to plain defaults instead of that error
          // recurring on every rebuild this Consumer triggers.
          ThemeData theme;
          try {
            theme = AppTheme.light(
              primaryColor: user != null ? _colorFromHex(user.themeColor) : null,
              secondaryColor: user != null ? _colorFromHex(user.themeColorSecondary) : null,
              fontFamily: user?.fontFamily,
              fontSizeScale: (user?.fontSize ?? 100) / 100,
            );
          } catch (e) {
            debugPrint('Theme construction failed, falling back to defaults: $e');
            theme = AppTheme.light();
          }
          return MaterialApp(
            title: 'My Digital Diary',
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const ConnectivityGate(child: AuthGate()),
          );
        },
      ),
    );
  }
}

/// Watches AuthService.status and shows whichever screen matches —
/// mirrors the web app's middleware-driven redirects (guest ->
/// verified/subscribed gates) but as a single Flutter widget tree switch
/// instead of separate HTTP routes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.loggedOut:
        return const LoginScreen();
      case AuthStatus.otpPending:
        return const OtpScreen();
      case AuthStatus.loggedIn:
        return const MainNavigationScreen();
    }
  }
}
