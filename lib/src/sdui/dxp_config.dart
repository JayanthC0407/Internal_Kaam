/// Build-time switches for the DXP runtime (CONTRACT-OBDX §10).
///
/// With [isOn] false the app is exactly today's app: nothing calls the
/// platform and every DXP surface draws nothing.
class DxpConfig {
  const DxpConfig._();

  static const bool _enabled = bool.fromEnvironment('DXP_ENABLED');

  /// Platform origin, e.g. `http://10.0.2.2:8090` for the Android emulator.
  static const String baseUrl = String.fromEnvironment('DXP_BASE_URL');

  /// One key per environment (CONTRACT-OBDX §12.4). The default matches the
  /// platform's local dev default only.
  static const String appKey = String.fromEnvironment(
    'DXP_APP_KEY',
    defaultValue: 'demo-bank-dev-key',
  );

  static const String appVersion = String.fromEnvironment(
    'DXP_APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// Contract id sent in the session handshake.
  static const String contract = 'obdx-1';

  /// Salt for the opaque `userRef` (CONTRACT-OBDX §1.1). POC value; a real
  /// deployment would keep it per environment.
  static const String userRefSalt = 'demo-bank-dxp-poc';

  static const String _appEnv =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// Plain `http://` only in dev, the same rule the app applies to OBDX.
  static bool get _urlAllowed =>
      baseUrl.startsWith('https://') ||
      (_appEnv == 'dev' && baseUrl.startsWith('http://'));

  static bool get isOn => _enabled && baseUrl.isNotEmpty && _urlAllowed;
}
