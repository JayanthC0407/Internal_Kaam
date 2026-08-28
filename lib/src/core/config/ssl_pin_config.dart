import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/core/config/env_config.dart';

/// SSL public-key / certificate pinning configuration (mobile Dio only).
///
/// Pin values are SHA-256 fingerprints (Base64), supplied via `--dart-define`
/// or CI secrets — never commit production pin values.
class SslPinConfig {
  SslPinConfig._();

  /// `true` | `false` | `auto` (default). Auto enables pinning for UAT/prod HTTPS
  /// when [pinFingerprints] is non-empty.
  static const String pinEnabledFlag =
      String.fromEnvironment('SSL_PIN_ENABLED', defaultValue: 'auto');

  /// Comma-separated Base64 SHA-256 certificate fingerprints.
  /// Optional `sha256/` prefix per entry.
  static const String pinFingerprintsRaw =
      String.fromEnvironment('SSL_PIN_SHA256', defaultValue: '');

  static List<String> get pinFingerprints {
    if (pinFingerprintsRaw.trim().isEmpty) return const [];
    return pinFingerprintsRaw
        .split(',')
        .map((e) => _normalizeFingerprint(e.trim()))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Hostname from [EnvConfig.baseUrl] used for optional host check.
  static String get pinnedHost {
    final url = EnvConfig.baseUrl;
    if (url.isEmpty) return '';
    return Uri.tryParse(url)?.host ?? '';
  }

  static bool get isExplicitlyDisabled => pinEnabledFlag == 'false';

  static bool get isExplicitlyEnabled => pinEnabledFlag == 'true';

  /// Whether Dio must validate the server cert against [pinFingerprints].
  static bool get shouldEnforcePinning {
    if (isExplicitlyDisabled) return false;
    if (pinFingerprints.isEmpty) return false;

    if (isExplicitlyEnabled) return true;

    // auto
    final url = EnvConfig.baseUrl.toLowerCase();
    if (!url.startsWith('https://')) return false;

    if (EnvConfig.isUat || EnvConfig.isProd) return true;

    // Release/profile dev builds talking to HTTPS still pin when pins are set.
    if (kReleaseMode) return true;

    return false;
  }

  /// UAT/prod HTTPS builds must declare pins unless pinning is explicitly off.
  static bool get mustDeclarePins {
    if (isExplicitlyDisabled) return false;
    if (pinFingerprints.isNotEmpty) return false;

    final url = EnvConfig.baseUrl.toLowerCase();
    if (!url.startsWith('https://')) return false;

    return EnvConfig.isUat || EnvConfig.isProd || kReleaseMode;
  }

  static void validateAtStartup() {
    if (!mustDeclarePins) return;
    throw StateError(
      'SSL_PIN_SHA256 is required for APP_ENV=${EnvConfig.appEnv} HTTPS builds. '
      'Pass --dart-define=SSL_PIN_SHA256=<base64-sha256-pins> or set '
      'SSL_PIN_ENABLED=false only for non-production testing. '
      'See docs/security.md.',
    );
  }

  static String _normalizeFingerprint(String value) {
    const prefix = 'sha256/';
    if (value.toLowerCase().startsWith(prefix)) {
      return value.substring(prefix.length);
    }
    return value;
  }
}
