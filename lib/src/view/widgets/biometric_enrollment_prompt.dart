import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
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
      // Already set up: renew the OBDX token quietly and go on. No extra
      // fingerprint prompt — the password already proved who this is, and
      // OBDX only asks about Alternate Login when it is not set up.
      await enrollment.refreshSetupTokenFromPendingQuietly();
      return;
    }
    if (!context.mounted) return;
    // Not set up: OBDX "Enable Alternate Login" sheet (Enable / Skip).
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

    await showEnableSheet(context, ref);
  }

  /// OBDX "Enable Alternate Login" (designer mock): a bottom sheet over
  /// the current screen with Enable and Skip. Returns true when enrolled.
  static Future<bool> showEnableSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (kIsWeb) return false;
    final enable = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => const _EnableAlternateLoginSheet(),
    );
    if (enable != true || !context.mounted) return false;
    return enableNow(context, ref);
  }

  /// Turns on biometric login: checks the device, offers Settings when no
  /// fingerprint / face is set up, then enrolls with OBDX. Shared by the
  /// sheet and [BiometricSetupScreen].
  static Future<bool> enableNow(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final biometrics = ref.read(biometricServiceProvider);
    final availability = await biometrics.checkAvailability();
    if (!context.mounted) return false;

    if (availability == BiometricAvailability.notSupported) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.biometricNotAvailable)),
      );
      return false;
    }

    if (availability == BiometricAvailability.notEnrolled) {
      final open = await AppBottomSheet.confirm(
        context,
        title: l10n.biometricNotEnrolledTitle,
        message: l10n.biometricNotEnrolled,
        confirmLabel: l10n.biometricOpenSettings,
        cancelLabel: l10n.cancel,
      );
      if (open) await biometrics.openBiometricSettings();
      return false;
    }

    final method = await biometrics.preferredLoginMethod();
    final outcome = await ref
        .read(biometricEnrollmentProvider)
        .enableBiometric(l10n, method: method);

    if (outcome.serverError != null && outcome.serverError!.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(outcome.serverError!)));
    }
    if (outcome.localResult == BiometricAuthResult.success &&
        outcome.serverEnrolled) {
      return true;
    }
    if (outcome.serverError == null &&
        outcome.localResult != BiometricAuthResult.cancelled) {
      final message = biometricResultMessage(l10n, outcome.localResult);
      final detail = biometrics.lastErrorDetail;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            kDebugMode && detail != null && detail.isNotEmpty
                ? '$message ($detail)'
                : message,
          ),
        ),
      );
    }
    return false;
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
    await showEnableSheet(context, ref);
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

class _EnableAlternateLoginSheet extends StatelessWidget {
  const _EnableAlternateLoginSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.altLoginEnableTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.altLoginEnableBody,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(
                l10n.altLoginEnable,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  l10n.lfwSkip,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
