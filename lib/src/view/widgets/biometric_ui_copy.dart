import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';

/// Labels and icons for the single biometric control (client-agreed UX).
class BiometricUiCopy {
  BiometricUiCopy._();

  static String enableLabel(
    AppLocalizations l10n,
    BiometricPresentation presentation,
  ) {
    return switch (presentation) {
      BiometricPresentation.android => l10n.biometricEnableLogin,
      BiometricPresentation.iosFaceId => l10n.biometricEnableFaceId,
      BiometricPresentation.iosTouchId => l10n.biometricEnableTouchId,
    };
  }

  static String? helperText(
    AppLocalizations l10n,
    BiometricPresentation presentation,
  ) {
    return presentation == BiometricPresentation.android
        ? l10n.biometricEnableLoginHelper
        : null;
  }

  static IconData icon(BiometricPresentation presentation) {
    return switch (presentation) {
      BiometricPresentation.android => Icons.fingerprint_rounded,
      BiometricPresentation.iosFaceId => Icons.face_rounded,
      BiometricPresentation.iosTouchId => Icons.fingerprint_rounded,
    };
  }
}
