import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'reminder_service.dart';
import 'branding_service.dart';

enum AuthStatus { unknown, loggedOut, otpPending, loggedIn }

/// App-wide auth state, provided at the root (see main.dart) via
/// ChangeNotifierProvider — screens read AuthService.status to decide
/// what to show, mirroring the web app's own three-state flow:
/// unauthenticated -> (password correct, OTP emailed) -> authenticated.
/// Nothing is "logged in" until verifyOtp() succeeds, exactly like the
/// web app's OtpVerificationController.
class AuthService extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  int? _pendingOtpUserId;
  bool _pendingRemember = true;

  // Local cache-busting signal for the protected avatar endpoint.
  int _avatarRevision = 0;
  int get avatarRevision => _avatarRevision;

  final _api = ApiClient.instance;

  Future<void> bootstrap() async {
    final token = await _api.getToken();
    if (token == null) {
      status = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }

    try {
      // Startup must be fast. Two seconds is enough to validate a healthy
      // connection; ApiClient can still serve the cached /me payload when the
      // network is unavailable. Do not use the normal 15-second request budget
      // for something that controls whether the splash screen disappears.
      final response = await _api
          .get('me', cacheable: true)
          .timeout(const Duration(seconds: 2));

      user = AppUser.fromJson(response['user']);
      status = AuthStatus.loggedIn;

      // Release the splash immediately. Push-token registration and reminder
      // synchronization are background maintenance and must never delay Home.
      notifyListeners();
      unawaited(_postLoginSetup());
      return;
    } on SocketException catch (_) {
      _handleOfflineBootstrap();
    } on http.ClientException catch (_) {
      _handleOfflineBootstrap();
    } on TimeoutException catch (_) {
      _handleOfflineBootstrap();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _api.clearToken();
        status = AuthStatus.loggedOut;
      } else {
        _handleOfflineBootstrap();
      }
    } catch (_) {
      _handleOfflineBootstrap();
    }

    notifyListeners();
  }

  Future<void> _postLoginSetup() async {
    try {
      await BrandingService().syncPreferredCurrency();
    } catch (_) {
      // Display-currency sync should never block startup or navigation.
    }
    try {
      await NotificationService.instance.registerDeviceToken();
    } catch (_) {
      // Network/Firebase availability should never affect navigation.
    }
    await _syncLocalReminderSchedules();
  }

  /// Reached when /me couldn't be verified for a reason that has
  /// nothing to do with whether the token is actually valid (no
  /// connection, unreachable server, etc.) — keeps the token. If a
  /// user object already exists (this session previously succeeded,
  /// or /me's own response was cached), shows the logged-in shell
  /// with that data. If genuinely nothing has ever loaded (token
  /// exists but /me has never once succeeded while online), stays in
  /// the loading state rather than claiming "logged in" with a null
  /// user, which would crash every screen assuming one exists.
  void _handleOfflineBootstrap() {
    // Never leave startup in AuthStatus.unknown indefinitely. If cached /me
    // data was available, `user` is already populated and the app continues.
    // If this installation has no cached profile yet, show Login rather than
    // trapping the user on a spinner. Keep the token untouched so the next
    // retry/start can validate it again when the API is reachable.
    status = user != null ? AuthStatus.loggedIn : AuthStatus.loggedOut;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _api.post('register', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'data_consent': true,
    }, auth: false);
    // Matches the web app: registering does not log you in on mobile
    // either — the caller's UI should direct the user to log in next.
  }

  /// Step 1 of 2. On success, `status` becomes `otpPending` — the UI
  /// should navigate to the OTP entry screen next.
  Future<void> login({required String email, required String password, bool remember = true}) async {
    final response = await _api.post('login', {'email': email, 'password': password}, auth: false);
    _pendingOtpUserId = response['user_id'] as int;
    _pendingRemember = remember;
    status = AuthStatus.otpPending;
    notifyListeners();
  }

  /// Step 2 of 2. Only this call actually produces a token / logged-in
  /// state.
  Future<void> verifyOtp(String code) async {
    if (_pendingOtpUserId == null) {
      throw StateError('No pending login — call login() first.');
    }

    final response = await _api.post('verify-otp', {
      'user_id': _pendingOtpUserId,
      'code': code,
    }, auth: false);

    await _api.saveToken(response['token'] as String, remember: _pendingRemember);
    user = AppUser.fromJson(response['user']);
    status = AuthStatus.loggedIn;
    _pendingOtpUserId = null;
    notifyListeners();

    unawaited(_postLoginSetup());
  }

  Future<void> _syncLocalReminderSchedules() async {
    try {
      final reminders = await ReminderService().list();
      await NotificationService.instance.syncReminderSchedules(reminders);
    } catch (_) {
      // A failed network sync must not remove schedules already stored by the
      // operating system from an earlier successful sync.
    }
  }

  Future<void> resendOtp() async {
    if (_pendingOtpUserId == null) return;
    await _api.post('resend-otp', {'user_id': _pendingOtpUserId}, auth: false);
  }

  /// Sends the reset email — same generic response either way, so
  /// nothing here reveals whether the address is actually registered.
  /// Completing the reset itself happens on the web (the link in that
  /// email opens the existing, already-working Breeze reset-password
  /// form in the phone's browser), not in this app.
  Future<String> forgotPassword(String email) async {
    final response = await _api.post('forgot-password', {'email': email}, auth: false);
    return response['message'] as String;
  }

  /// AppUser's fields are all final, so this rebuilds a new instance
  /// with just alarmsMuted changed, copying everything else across —
  /// avoids a full re-fetch just to reflect one flag flipping after
  /// the bell icon is tapped.
  void updateAlarmsMuted(bool muted) {
    if (user == null) return;
    user = user!.copyWith(alarmsMuted: muted);
    notifyListeners();
  }

  void updateAppearance({String? themeColor, String? themeColorSecondary, String? fontFamily, int? fontSize}) {
    if (user == null) return;
    user = user!.copyWith(
      themeColor: themeColor,
      themeColorSecondary: themeColorSecondary,
      fontFamily: fontFamily,
      fontSize: fontSize,
    );
    notifyListeners();
  }

  void updateProfileFields({String? name, String? email, String? avatarUrl}) {
    if (user == null) return;
    user = user!.copyWith(name: name, email: email, avatarUrl: avatarUrl);
    notifyListeners();
  }

  /// Call after Laravel confirms that a new profile image was stored.
  /// The revision forces Profile/Edit Profile/Drawer to reload the protected
  /// avatar stream even when the public avatar URL itself has not changed.
  void markAvatarUpdated({String? avatarUrl}) {
    if (user != null && avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      user = user!.copyWith(avatarUrl: avatarUrl);
    }
    _avatarRevision++;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await NotificationService.instance.unregisterDeviceToken();
      await _api.post('logout', {});
    } catch (_) {
      // Even if the server call fails (e.g. no connection), still clear
      // the local token below — a user tapping "Log out" should always
      // end up logged out locally, regardless of network state.
    }
    await _api.clearToken();
    user = null;
    status = AuthStatus.loggedOut;
    notifyListeners();
  }
}
