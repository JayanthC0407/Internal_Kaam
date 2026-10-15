import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/infra/session/session_manager.dart';

/// Decides when local biometric / PIN / pattern unlock should be shown.
class BiometricUnlockPolicy {
  BiometricUnlockPolicy._();

  /// Quick unlock when session JWT is still valid (6.5a).
  static Future<bool> shouldRequireUnlock({
    required SessionManager session,
    required PreferenceHelper preferences,
    required BiometricService biometrics,
  }) async {
    if (kIsWeb) return false;
    if (!await preferences.isBiometricEnabled()) return false;
    if (!await session.isAuthenticated()) return false;
    if (await session.isSessionExpired()) return false;

    final method = await preferences.getAlternateLoginMethod();
    if (method == null || method.isBiometric) {
      return biometrics.canAuthenticate();
    }
    return method.requiresLocalSecret;
  }

  /// Cold start token login (6.5b) — disabled for Grow-style flow:
  /// after logout, user signs in with password first, then biometric.
  static Future<bool> shouldShowColdStartBiometricLogin({
    required SessionManager session,
    required PreferenceHelper preferences,
    required BiometricService biometrics,
  }) async {
    return false;
  }

  /// Login-screen fingerprint (OBDX alternate login, designer mock: "or" +
  /// fingerprint under Login). Offered only on a phone that finished
  /// biometric enrollment with OBDX — biometrics on, the server setup token
  /// stored, and a fingerprint/face the device can still verify. The token
  /// login falls back to password if OBDX rejects the token.
  static Future<bool> canOfferQuickLogin({
    required PreferenceHelper preferences,
    required BiometricService biometrics,
  }) async {
    if (kIsWeb) return false;
    if (!await preferences.isBiometricEnabled()) return false;
    if (!await preferences.isBiometricServerEnrolled()) return false;
    if (!await preferences.hasBiometricSetupToken()) return false;
    final method = await preferences.getAlternateLoginMethod();
    if (method != null && !method.isBiometric) return false;
    return biometrics.canAuthenticate();
  }
}
