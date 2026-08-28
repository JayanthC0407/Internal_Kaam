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

  /// Login-screen quick login — same as cold start: password first after logout.
  static Future<bool> canOfferQuickLogin({
    required PreferenceHelper preferences,
    required BiometricService biometrics,
  }) async {
    return false;
  }
}
