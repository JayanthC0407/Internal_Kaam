import 'package:flutter/foundation.dart';
import 'package:demo_bank/src/core/config/env_config.dart';

/// Settings for the AI assistant (Noor) integration.
///
/// DEVELOPMENT ONLY. The assistant backend reads the signed-in user's OBDX data
/// read-only, using the app's own OBDX session handed over through a
/// development-only endpoint (a stand-in for a token exchange with the bank's
/// identity service). So it is switched off unless `APP_ENV` is `dev`.
///
/// `--dart-define`s:
/// - `ASSISTANT_API_URL`: the assistant backend's regional endpoint, ending in `/`.
///   On web in dev it defaults to the local backend `http://localhost:8080/gcc/`.
/// - `ASSISTANT_TENANT_ID`: this bank's tenant on the assistant platform.
class AssistantSettings {
  AssistantSettings._();

  static const String _apiUrl = String.fromEnvironment('ASSISTANT_API_URL');
  static const String tenantId =
      String.fromEnvironment('ASSISTANT_TENANT_ID', defaultValue: 'demobank-ae');

  /// The endpoint, or null when the assistant is off.
  static Uri? get apiBase {
    if (!EnvConfig.isDev) return null;
    final url = _apiUrl.isNotEmpty ? _apiUrl : (kIsWeb ? 'http://localhost:8080/gcc/' : '');
    return url.isEmpty ? null : Uri.tryParse(url);
  }

  static bool get enabled => apiBase != null;
}
