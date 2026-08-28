import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/obdx_error.dart';

extension AppLocalizationsErrors on AppLocalizations {
  String messageForObdxError(ObdxError error) {
    final key = error.l10nKey;
    final detail = error.detail?.trim();
    final hasApiDetail = detail != null && detail.isNotEmpty;

    // Prefer exact OBDX title/detail whenever the API sent one — including OTP
    // failures (DIGX_TFA_*) where the server message is the user-facing text.
    if (hasApiDetail &&
        (key == null ||
            key == 'errorGeneric' ||
            key == 'errorUnexpected' ||
            key == 'errorOtpInvalid' ||
            key == 'errorInvalidRequest')) {
      return detail;
    }

    if (key != null) {
      final mapped = _byKey(key);
      if (mapped != null) return mapped;
    }
    if (hasApiDetail) return detail;
    return error.userMessage;
  }

  String? _byKey(String key) => switch (key) {
        'errorInvalidCredentials' => errorInvalidCredentials,
        'errorAccountLocked' => errorAccountLocked,
        'errorPasswordExpired' => errorPasswordExpired,
        'errorTooManyAttempts' => errorTooManyAttempts,
        'errorSessionExpired' => errorSessionExpired,
        'errorTimeout' => errorTimeout,
        'errorBadCertificate' => errorBadCertificate,
        'errorCancelled' => errorCancelled,
        'errorAuthFailed' => errorAuthFailed,
        'errorForbidden' => errorForbidden,
        'errorNotFound' => errorNotFound,
        'errorServerUnavailable' => errorServerUnavailable,
        'errorInvalidRequest' => errorInvalidRequest,
        'errorNetwork' => errorNetwork,
        'errorUnexpected' => errorUnexpected,
        'errorGeneric' => errorGeneric,
        'errorOtpInvalid' => errorOtpInvalid,
        'errorUserAlreadyExists' => errorUserAlreadyExists,
        'otpResendUnavailable' => otpResendUnavailable,
        'errorBiometricAccessPoint' => errorBiometricAccessPoint,
        _ => null,
      };
}
