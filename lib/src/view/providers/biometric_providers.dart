import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/alternate_login_method.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/repositories/biometric_repository.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/view/providers/repository_providers.dart';
import 'package:ubci_bank/src/view/providers/session_providers.dart';

final biometricServiceProvider = Provider((_) => BiometricService());

final biometricLockProvider = StateProvider<bool>((ref) => false);

final biometricEnrollmentProvider = Provider(
  (ref) => BiometricEnrollmentController(
    biometrics: ref.watch(biometricServiceProvider),
    preferences: ref.watch(preferenceHelperProvider),
    biometricRepository: ref.watch(biometricRepositoryProvider),
  ),
);

class BiometricEnableOutcome {
  const BiometricEnableOutcome({
    required this.localResult,
    required this.serverEnrolled,
    this.serverError,
  });

  final BiometricAuthResult localResult;
  final bool serverEnrolled;
  final String? serverError;

  bool get success => localResult == BiometricAuthResult.success;
}

class BiometricEnrollmentController {
  BiometricEnrollmentController({
    required BiometricService biometrics,
    required PreferenceHelper preferences,
    required BiometricRepository biometricRepository,
  })  : _biometrics = biometrics,
        _preferences = preferences,
        _biometricRepository = biometricRepository;

  final BiometricService _biometrics;
  final PreferenceHelper _preferences;
  final BiometricRepository _biometricRepository;

  Future<bool> isEnabled() => _preferences.isBiometricEnabled();

  Future<bool> isServerEnrolled() => _preferences.isBiometricServerEnrolled();

  Future<bool> canEnroll() async {
    if (kIsWeb) return false;
    return _biometrics.canAuthenticate();
  }

  Future<AlternateLoginMethod?> activeMethod() =>
      _preferences.getAlternateLoginMethod();

  /// Face ID / Fingerprint: local_auth gate + plaintext token in secure storage.
  Future<BiometricEnableOutcome> enableBiometric(
    AppLocalizations l10n, {
    required AlternateLoginMethod method,
  }) async {
    if (kIsWeb) {
      return const BiometricEnableOutcome(
        localResult: BiometricAuthResult.notAvailable,
        serverEnrolled: false,
      );
    }
    assert(method.isBiometric);
    final result = await _biometrics.authenticate(
      reason: l10n.biometricEnableReason,
    );
    if (result != BiometricAuthResult.success) {
      return BiometricEnableOutcome(localResult: result, serverEnrolled: false);
    }

    final tokenResult = await _ensurePlaintextSetupToken();
    if (tokenResult.error != null) {
      return BiometricEnableOutcome(
        localResult: result,
        serverEnrolled: false,
        serverError: tokenResult.error,
      );
    }

    await _preferences.setBiometricSetupToken(tokenResult.token!);
    await _preferences.setBiometricServerEnrolled(true);
    await _preferences.setAlternateLoginMethod(method);
    await _preferences.setBiometricEnabled(true);

    return BiometricEnableOutcome(
      localResult: result,
      serverEnrolled: true,
    );
  }

  /// Passcode / Pattern: encrypt jwtoken with the local secret.
  Future<BiometricEnableOutcome> enableWithLocalSecret({
    required AlternateLoginMethod method,
    required String secret,
    required AppLocalizations l10n,
  }) async {
    if (kIsWeb) {
      return const BiometricEnableOutcome(
        localResult: BiometricAuthResult.notAvailable,
        serverEnrolled: false,
      );
    }
    assert(method.requiresLocalSecret);
    if (secret.isEmpty) {
      return BiometricEnableOutcome(
        localResult: BiometricAuthResult.failed,
        serverEnrolled: false,
        serverError: l10n.passcodeInvalid,
      );
    }

    final tokenResult = await _ensurePlaintextSetupToken();
    if (tokenResult.error != null) {
      return BiometricEnableOutcome(
        localResult: BiometricAuthResult.failed,
        serverEnrolled: false,
        serverError: tokenResult.error,
      );
    }

    await _preferences.setEncryptedBiometricSetupToken(
      plaintextToken: tokenResult.token!,
      secret: secret,
    );
    await _preferences.setBiometricServerEnrolled(true);
    await _preferences.setAlternateLoginMethod(method);
    await _preferences.setBiometricEnabled(true);

    return const BiometricEnableOutcome(
      localResult: BiometricAuthResult.success,
      serverEnrolled: true,
    );
  }

  /// Legacy entry used by older call sites — Face/Fingerprint path.
  Future<BiometricEnableOutcome> enable(AppLocalizations l10n) {
    return enableBiometric(l10n, method: AlternateLoginMethod.fingerprint);
  }

  Future<({String? token, String? error})> _ensurePlaintextSetupToken() async {
    // Reuse an existing plaintext setup token (Face/Fingerprint, or leftover
    // after soft-disable of a biometric method).
    if (!await _preferences.isSetupTokenEncrypted()) {
      final existing = await _preferences.getBiometricSetupToken();
      if (existing != null && existing.isNotEmpty) {
        return (token: existing, error: null);
      }
    }

    // After Passcode/Pattern soft-disable the encrypted token is cleared; a
    // fresh /jwt enrollment needs credentials from the current password session.
    final pending = await _preferences.getPendingBiometricEnrollment();
    if (pending == null) {
      return (
        token: null,
        error:
            'Quick access requires a recent password login. Sign in again, then retry.',
      );
    }

    final serverResult =
        await _biometricRepository.enrollServerBiometricFromPending();
    if (serverResult is! Success<void>) {
      final error = serverResult is Error<void> ? serverResult.error : null;
      return (
        token: null,
        error: error ?? 'Could not register this device for quick access.',
      );
    }

    final token = await _preferences.getBiometricSetupToken();
    if (token == null || token.isEmpty) {
      return (token: null, error: 'JWT setup token is missing after enrollment.');
    }
    return (token: token, error: null);
  }

  /// Soft-disable from More settings — keeps server enrollment / pending
  /// credentials so the user can re-enable without signing in again.
  Future<void> disable() async {
    await _preferences.disableLocalQuickAccess();
  }

  /// After password login, renew OBDX setup token in the background when
  /// biometrics are already enabled (no setup UI). Best-effort — failures
  /// are ignored so login is not blocked.
  Future<void> refreshSetupTokenFromPendingQuietly() async {
    if (kIsWeb) return;
    if (!await _preferences.isBiometricEnabled()) return;
    final pending = await _preferences.getPendingBiometricEnrollment();
    if (pending == null) return;
    try {
      await _biometricRepository.enrollServerBiometricFromPending();
    } catch (_) {
      // Best-effort renewal only.
    }
  }
}

String biometricResultMessage(AppLocalizations l10n, BiometricAuthResult result) {
  return switch (result) {
    BiometricAuthResult.success => l10n.biometricEnabledSuccess,
    BiometricAuthResult.cancelled => l10n.biometricCancelled,
    BiometricAuthResult.notEnrolled => l10n.biometricNotEnrolled,
    BiometricAuthResult.notAvailable => l10n.biometricNotAvailable,
    BiometricAuthResult.lockedOut => l10n.biometricTemporarilyLocked,
    BiometricAuthResult.failed => l10n.biometricAuthFailed,
  };
}
