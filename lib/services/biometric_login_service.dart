import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class BiometricLoginState {
  final bool deviceSupported;
  final bool fingerprintEnrolled;
  final bool enabled;
  final bool hasRememberedSession;
  final String? accountLabel;

  const BiometricLoginState({
    required this.deviceSupported,
    required this.fingerprintEnrolled,
    required this.enabled,
    required this.hasRememberedSession,
    required this.accountLabel,
  });

  bool get canOfferLogin =>
      deviceSupported &&
      fingerprintEnrolled &&
      enabled &&
      hasRememberedSession;
}

class BiometricLoginException implements Exception {
  final String message;

  const BiometricLoginException(this.message);

  @override
  String toString() => message;
}

class BiometricLoginService {
  BiometricLoginService._();

  static final BiometricLoginService instance = BiometricLoginService._();

  static const _enabledKey = 'biometric_login_enabled';
  static const _accountLabelKey = 'biometric_login_account_label';

  final LocalAuthentication _auth = LocalAuthentication();

  Future<BiometricLoginState> state() async {
    final prefs = await SharedPreferences.getInstance();

    bool supported = false;
    bool fingerprintEnrolled = false;

    try {
      supported =
          await _auth.isDeviceSupported() || await _auth.canCheckBiometrics;

      final available = await _auth.getAvailableBiometrics();

      fingerprintEnrolled =
          available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong) ||
          available.contains(BiometricType.weak);
    } catch (_) {
      supported = false;
      fingerprintEnrolled = false;
    }

    final token = await ApiClient.instance.getToken();

    return BiometricLoginState(
      deviceSupported: supported,
      fingerprintEnrolled: fingerprintEnrolled,
      enabled: prefs.getBool(_enabledKey) ?? false,
      hasRememberedSession: token != null && token.trim().isNotEmpty,
      accountLabel: prefs.getString(_accountLabelKey),
    );
  }

  Future<void> enableForCurrentAccount({
    String? accountLabel,
  }) async {
    final current = await state();

    if (!current.deviceSupported) {
      throw const BiometricLoginException(
        'Fingerprint login is not supported on this device.',
      );
    }

    if (!current.fingerprintEnrolled) {
      throw const BiometricLoginException(
        'No fingerprint is enrolled on this phone. Add a fingerprint in your device settings first.',
      );
    }

    if (!current.hasRememberedSession) {
      throw const BiometricLoginException(
        'Sign in with Remember Me enabled before turning on fingerprint login.',
      );
    }

    final authenticated = await _authenticate(
      reason: 'Confirm your fingerprint to enable fingerprint login.',
    );

    if (!authenticated) {
      throw const BiometricLoginException(
        'Fingerprint verification was cancelled or unsuccessful.',
      );
    }

    // Confirm that the saved Sanctum token is still valid before enabling.
    try {
      await ApiClient.instance.get('me');
    } catch (_) {
      throw const BiometricLoginException(
        'Your saved session is no longer valid. Sign in with your password again first.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);

    final label = accountLabel?.trim();
    if (label != null && label.isNotEmpty) {
      await prefs.setString(_accountLabelKey, label);
    }
  }

  Future<Map<String, dynamic>> authenticateAndRestoreSession() async {
    final current = await state();

    if (!current.enabled) {
      throw const BiometricLoginException(
        'Fingerprint login has not been enabled for this device.',
      );
    }

    if (!current.fingerprintEnrolled) {
      throw const BiometricLoginException(
        'Fingerprint is unavailable. Use your email and password instead.',
      );
    }

    if (!current.hasRememberedSession) {
      await disable();

      throw const BiometricLoginException(
        'Your remembered session is no longer available. Sign in normally and enable fingerprint login again.',
      );
    }

    final authenticated = await _authenticate(
      reason: 'Use your fingerprint to sign in to My Digital Diary.',
    );

    if (!authenticated) {
      throw const BiometricLoginException(
        'Fingerprint verification was cancelled or unsuccessful.',
      );
    }

    try {
      final response = await ApiClient.instance.get('me');

      if (response is Map<String, dynamic>) {
        return response;
      }

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      return <String, dynamic>{};
    } catch (_) {
      await disable();

      throw const BiometricLoginException(
        'Your saved login has expired. Sign in with your password again.',
      );
    }
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_accountLabelKey);
  }

  Future<bool> _authenticate({
    required String reason,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
          throw const BiometricLoginException(
            'This device does not have supported biometric hardware.',
          );
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          throw const BiometricLoginException(
            'No fingerprint is enrolled on this phone. Add one in device settings first.',
          );
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          throw const BiometricLoginException(
            'Fingerprint authentication is temporarily locked. Use your password or unlock the phone first.',
          );
        default:
          throw const BiometricLoginException(
            'Fingerprint authentication could not be completed.',
          );
      }
    } catch (_) {
      throw const BiometricLoginException(
        'Fingerprint authentication could not be completed.',
      );
    }
  }
}
