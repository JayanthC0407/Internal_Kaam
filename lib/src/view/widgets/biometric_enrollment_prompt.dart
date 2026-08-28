import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';

/// Post-login biometric UX (mobile only).
///
/// Grow-style: after password login, if biometrics are already enabled, prompt
/// for fingerprint/Face (no re-setup). If not enabled, offer setup once.
class BiometricEnrollmentPrompt {
  BiometricEnrollmentPrompt._();

  /// Call after successful password / OTP login before navigating home.
  static Future<void> afterPasswordLogin(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (kIsWeb) return;
    final enrollment = ref.read(biometricEnrollmentProvider);
    if (await enrollment.isEnabled()) {
      await enrollment.refreshSetupTokenFromPendingQuietly();
      if (!context.mounted) return;
      await _challengeExistingBiometric(context, ref);
      return;
    }
    if (!context.mounted) return;
    await offerIfNeeded(context, ref);
  }

  static Future<void> offerIfNeeded(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (kIsWeb) return;
    final enrollment = ref.read(biometricEnrollmentProvider);
    if (await enrollment.isEnabled()) return;
    if (!context.mounted) return;

    await Navigator.of(context).pushNamed(RoutesConst.biometricSetupScreen);
  }

  /// Local biometric gate when quick access is already enrolled (Grow-style).
  static Future<void> _challengeExistingBiometric(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final enrollment = ref.read(biometricEnrollmentProvider);
    final method = await enrollment.activeMethod();
    // Passcode/pattern are verified on unlock screens; after password login
    // Face/Fingerprint use the system prompt only.
    if (method != null && method.requiresLocalSecret) return;
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final biometrics = ref.read(biometricServiceProvider);
    final reason = l10n.biometricUnlockReason;

    // Best-effort: password session is already valid. Retry once on cancel.
    var result = await biometrics.authenticate(reason: reason);
    if (result == BiometricAuthResult.success) return;
    if (!context.mounted) return;

    result = await biometrics.authenticate(reason: reason);
    if (result == BiometricAuthResult.success) return;
    // Session already established via password — continue to home.
  }

  static Future<void> enableFromSettings(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (kIsWeb) return;
    final l10n = AppLocalizations.of(context);

    if (!await sessionIsActive(ref)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorSessionExpired)),
      );
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).pushNamed(RoutesConst.biometricSetupScreen);
  }

  static Future<void> disableFromSettings(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (kIsWeb) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppBottomSheet.confirm(
      context,
      title: l10n.security,
      message: l10n.biometricDisableConfirm,
      destructive: true,
    );

    if (!confirmed) return;
    await ref.read(biometricEnrollmentProvider).disable();
    ref.read(biometricLockProvider.notifier).state = false;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.biometricDisabledSuccess)),
    );
  }

  static Future<bool> sessionIsActive(WidgetRef ref) async {
    final session = ref.read(sessionManagerProvider);
    if (!await session.isAuthenticated()) return false;
    if (await session.isSessionExpired()) return false;
    return true;
  }
}
