import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/core/config/app_config.dart';
import 'package:ubci_bank/src/core/constants/adlog.dart';

/// Runtime configuration from `--dart-define` / CI build args.
/// See `docs/setup.md` and `.env.example` (local copy as `.env`, never committed).
class EnvConfig {
  EnvConfig._();

  static const String obdxBaseUrl = String.fromEnvironment('OBDX_BASE_URL');
  static const String obdxWebFallbackUrl =
      String.fromEnvironment('OBDX_WEB_FALLBACK_URL');
  static const String obdxSessionInitPaths =
      String.fromEnvironment('OBDX_INIT_SESSION_PATH');
  static const String appEnv =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// OBDX touch point for `/digx-admin/sms/v1/jwt` (default `APMOBAPP` per xlsx).
  static const String obdxJwtAccessPointId = String.fromEnvironment(
    'OBDX_JWT_ACCESS_POINT_ID',
    defaultValue: 'APMOBAPP',
  );

  static String get jwtAccessPointId {
    final id = obdxJwtAccessPointId.trim();
    return id.isEmpty ? 'APMOBAPP' : id;
  }

  static bool get isDev => appEnv == 'dev';
  static bool get isUat => appEnv == 'uat';
  static bool get isProd => appEnv == 'prod';

  /// Whether [OBDX_BASE_URL] was passed via `--dart-define` / `run_app.sh`.
  static bool get isConfigured => baseUrl.isNotEmpty;

  /// Logs setup instructions for developers; no-op in release.
  static void logMissingBaseUrlIfNeeded() {
    if (!kDebugMode || isConfigured) return;
    adLog(
      'OBDX_BASE_URL is not set. Copy .env.example to .env, set OBDX_BASE_URL, '
      'then run ./scripts/run_app.sh or ./scripts/sync_ide_config.sh. '
      'See docs/setup.md.',
    );
  }

  /// Warns when Flutter web targets a non-localhost API (browser CORS will fail).
  static void logWebCorsHintIfNeeded() {
    if (!kDebugMode || !kIsWeb) return;
    final url = webFallbackUrl.isNotEmpty ? webFallbackUrl : baseUrl;
    if (url.isEmpty) return;
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host == 'localhost' || host == '127.0.0.1') return;
    adLog(
      'Flutter web is calling $url directly. Browsers block this (CORS) unless '
      'that origin reverse-proxies /digx-* to OBDX. '
      'Prefer: run `node proxy.js` and set OBDX_WEB_FALLBACK_URL to the proxy '
      '(e.g. http://localhost:8082 or http://<lan-host>:8082). '
      'Never point OBDX_BASE_URL at the Flutter static web port alone. '
      'See docs/setup.md.',
    );
  }

  /// Normalized OBDX base URL, or empty when not configured.
  static String get baseUrl => _normalizeUrl(obdxBaseUrl);

  /// Web fallback URL; falls back to [baseUrl] when unset.
  static String get webFallbackUrl {
    final fallback = obdxWebFallbackUrl.trim();
    if (fallback.isEmpty) return baseUrl;
    return _normalizeUrl(fallback);
  }

  /// Validates configured URLs at app startup (fail fast before network calls).
  static void validateAtStartup() {
    final primary = baseUrl;
    if (primary.isNotEmpty) {
      _validateTransportSecurity(primary);
    }

    final fallbackRaw = obdxWebFallbackUrl.trim();
    if (fallbackRaw.isNotEmpty) {
      _validateTransportSecurity(_normalizeUrl(fallbackRaw));
    }
  }

  static String requireBaseUrl() {
    final url = baseUrl;
    if (url.isEmpty) {
      throw StateError(
        'OBDX_BASE_URL is not set. '
        'Pass --dart-define=OBDX_BASE_URL=<your-api-host> or use scripts/run_app.sh '
        'with a local .env file. See docs/setup.md.',
      );
    }
    _validateTransportSecurity(url);
    return url;
  }

  static List<String> get sessionInitPaths {
    final raw = obdxSessionInitPaths.trim();
    if (raw.isNotEmpty) {
      return raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return List<String>.from(AppConfig.obdxSessionInitPaths);
  }

  /// Cleartext HTTP is permitted only when [APP_ENV] is `dev`
  /// (debug, profile, or release). UAT/prod always require HTTPS.
  static bool get isCleartextHttpPermitted => isDev;

  static void _validateTransportSecurity(String url) {
    final lower = url.toLowerCase();

    if (lower.startsWith('https://')) {
      return;
    }

    if (lower.startsWith('http://')) {
      if (isCleartextHttpPermitted) {
        return;
      }
      throw StateError(
        'Cleartext HTTP is not allowed for APP_ENV=$appEnv. '
        'Use an https:// OBDX_BASE_URL (or APP_ENV=dev for local HTTP). '
        'See docs/security.md.',
      );
    }

    throw StateError(
      'OBDX URL must start with https:// '
      '(or http:// only when APP_ENV=dev): $url',
    );
  }

  static String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
