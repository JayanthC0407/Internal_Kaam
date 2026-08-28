import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ubci_bank/src/core/constants/adlog.dart';
import 'package:ubci_bank/src/core/models/alternate_login_method.dart';

enum BiometricAvailability {
  available,
  notEnrolled,
  notSupported,
}

enum BiometricAuthResult {
  success,
  cancelled,
  notEnrolled,
  notAvailable,
  lockedOut,
  failed,
}

/// Single biometric control labels — apps cannot pick the sensor.
enum BiometricPresentation {
  android,
  iosFaceId,
  iosTouchId,
}

/// Device biometric authentication (fingerprint / Face ID).
/// Web is unsupported — callers should gate with [kIsWeb].
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// True while a system biometric prompt is showing.
  /// Used to avoid treating prompt-driven lifecycle pauses as app backgrounding.
  static bool isAuthInProgress = false;

  /// Single in-flight auth so concurrent callers share one native prompt.
  static Future<BiometricAuthResult>? _inFlightAuth;

  /// Last platform error detail (debug builds only) for troubleshooting.
  String? lastErrorDetail;

  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (e, st) {
      adLogError(e, st);
      return false;
    }
  }

  Future<BiometricAvailability> checkAvailability() async {
    if (kIsWeb) return BiometricAvailability.notSupported;
    try {
      if (!await _auth.isDeviceSupported()) {
        return BiometricAvailability.notSupported;
      }
      if (!await _auth.canCheckBiometrics) {
        return BiometricAvailability.notEnrolled;
      }
      return BiometricAvailability.available;
    } catch (e, st) {
      adLogError(e, st);
      return BiometricAvailability.notSupported;
    }
  }

  Future<bool> canAuthenticate() async {
    final availability = await checkAvailability();
    return availability == BiometricAvailability.available;
  }

  /// Enrolled biometric types reported by the OS (`face`, `fingerprint`,
  /// and/or Android `strong` / `weak` classifications).
  Future<List<BiometricType>> getEnrolledBiometrics() async {
    if (kIsWeb) return const [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e, st) {
      adLogError(e, st);
      return const [];
    }
  }

  /// Platform-aware label for the single biometric control.
  ///
  /// iOS reports Face ID vs Touch ID from hardware even when nothing is
  /// enrolled. Android always uses the generic biometric label because the OS
  /// chooses the sensor (Class 3 fingerprint on virtually all devices).
  Future<BiometricPresentation> presentation() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final types = await getEnrolledBiometrics();
      if (types.contains(BiometricType.fingerprint) &&
          !types.contains(BiometricType.face)) {
        return BiometricPresentation.iosTouchId;
      }
      return BiometricPresentation.iosFaceId;
    }
    return BiometricPresentation.android;
  }

  /// Stored method for the single biometric control.
  Future<AlternateLoginMethod> preferredLoginMethod() async {
    final kind = await presentation();
    return kind == BiometricPresentation.iosFaceId
        ? AlternateLoginMethod.faceId
        : AlternateLoginMethod.fingerprint;
  }

  /// Opens OS security / lock-screen settings so the user can enroll biometrics.
  Future<void> openBiometricSettings() async {
    if (kIsWeb) return;
    try {
      await AppSettings.openAppSettings(
        type: AppSettingsType.lockAndPassword,
      );
    } catch (e, st) {
      adLogError(e, st);
      try {
        await AppSettings.openAppSettings();
      } catch (e2, st2) {
        adLogError(e2, st2);
      }
    }
  }

  /// Authenticates with biometrics. Concurrent calls join the same in-flight
  /// prompt instead of starting a second one (`authInProgress`).
  Future<BiometricAuthResult> authenticate({required String reason}) {
    lastErrorDetail = null;
    if (kIsWeb) {
      return Future.value(BiometricAuthResult.notAvailable);
    }

    final existing = _inFlightAuth;
    if (existing != null) {
      adLog('Biometric auth joined in-flight prompt');
      return existing;
    }

    // Assign before any await so concurrent callers always join.
    final future = _authenticateExclusive(reason);
    _inFlightAuth = future;
    return future.whenComplete(() {
      if (identical(_inFlightAuth, future)) {
        _inFlightAuth = null;
      }
    });
  }

  Future<BiometricAuthResult> _authenticateExclusive(String reason) async {
    final availability = await checkAvailability();
    if (availability == BiometricAvailability.notEnrolled) {
      return BiometricAuthResult.notEnrolled;
    }
    if (availability == BiometricAvailability.notSupported) {
      return BiometricAuthResult.notAvailable;
    }

    // Do NOT toggle FLAG_SECURE around the prompt. Disable→enable races
    // dismiss the first success as systemCanceled; Try again then works.
    isAuthInProgress = true;
    try {
      return await _authenticateWithBiometrics(reason);
    } finally {
      isAuthInProgress = false;
    }
  }

  Future<BiometricAuthResult> _authenticateWithBiometrics(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        // Samsung / Face ID: confirmation step can cause confusing failures.
        sensitiveTransaction: false,
        // Keep the prompt alive across brief activity pauses.
        persistAcrossBackgrounding: true,
      );
      if (ok) return BiometricAuthResult.success;
      lastErrorDetail = 'Authentication returned false';
      adLog('Biometric auth failed: $lastErrorDetail');
      return BiometricAuthResult.failed;
    } on LocalAuthException catch (e) {
      lastErrorDetail = e.description;
      adLog('Biometric auth exception: ${e.code.name} ${e.description ?? ''}');
      return _mapException(e);
    } catch (e, st) {
      adLogError(e, st);
      lastErrorDetail = e.toString();
      return BiometricAuthResult.failed;
    }
  }

  BiometricAuthResult _mapException(LocalAuthException e) {
    switch (e.code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.userRequestedFallback:
      // Temporary / race conditions — prompt user to try again (not "unsupported").
      case LocalAuthExceptionCode.authInProgress:
      case LocalAuthExceptionCode.uiUnavailable:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return BiometricAuthResult.cancelled;
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return BiometricAuthResult.notEnrolled;
      case LocalAuthExceptionCode.noBiometricHardware:
        return BiometricAuthResult.notAvailable;
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return BiometricAuthResult.lockedOut;
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return BiometricAuthResult.failed;
    }
  }
}
