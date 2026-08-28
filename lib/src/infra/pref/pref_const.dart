class PrefConst {
  /// Secure storage — session JWT.
  static const String loggedInAuthorization = 'obdxAuthorization';

  /// Secure storage — OBDX session cookies (JSON).
  static const String loggedInCookies = 'obdxCookies';

  /// Secure storage — biometric quick-login enabled flag.
  static const String biometricEnabled = 'biometricEnabled';

  /// Secure storage — install-scoped device id for OBDX mobileClient / token login.
  static const String obdxSecureDeviceId = 'obdxSecureDeviceId';

  /// Secure storage — JWT setup token (`jwtoken`) from `/digx-admin/sms/v1/jwt`.
  /// Plaintext for Face/Fingerprint; AES-encrypted for Passcode/Pattern.
  static const String obdxBiometricSetupToken = 'obdxBiometricSetupToken';

  /// Secure storage — `true` when [obdxBiometricSetupToken] is PIN/pattern-encrypted.
  static const String obdxSetupTokenEncrypted = 'obdxSetupTokenEncrypted';

  /// Secure storage — active [AlternateLoginMethod] name.
  static const String alternateLoginMethod = 'alternateLoginMethod';

  /// Secure storage — `true` when mobileClient + jwt enrollment succeeded.
  static const String obdxBiometricServerEnrolled = 'obdxBiometricServerEnrolled';

  /// Secure storage — encrypted password for server enrollment
  /// (cleared on logout / forget device; kept after enroll so More-tab
  /// disable → re-enable can call `/jwt` again in the same session).
  static const String obdxPendingBiometricEncryptedPassword =
      'obdxPendingBiometricEncryptedPassword';

  /// Secure storage — username paired with pending biometric enrollment.
  static const String obdxPendingBiometricUserName = 'obdxPendingBiometricUserName';

  /// Secure storage — plain password for JWT setup
  /// (cleared on logout / forget device; kept after enroll for same-session re-enable).
  static const String obdxPendingBiometricPlainPassword =
      'obdxPendingBiometricPlainPassword';

  /// Secure storage — last successful login username (non-secret).
  static const String lastUserName = 'lastUserName';

  /// Secure storage — display name for dashboard greeting.
  static const String lastDisplayName = 'lastDisplayName';

  /// Secure storage — ISO-8601 last user activity timestamp.
  static const String lastSessionActivityAt = 'lastSessionActivityAt';

  /// Secure storage — keep session across app restarts (`true` when unset).
  static const String keepSignedIn = 'keepSignedIn';

  /// SharedPreferences — one-time migration flag (non-sensitive).
  static const String secureStorageMigrated = 'secureStorageMigrated_v1';

  /// SharedPreferences — app theme mode (`light` / `dark` / `system`).
  static const String themeMode = 'themeMode';

  /// SharedPreferences — app locale language code (e.g. `en`).
  static const String appLocale = 'appLocale';
}
