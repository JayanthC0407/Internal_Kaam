import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/core/config/env_config.dart';

/// Screenshot / screen-recording protection policy for sensitive screens.
class ScreenSecurityConfig {
  ScreenSecurityConfig._();

  static const String enabledFlag = String.fromEnvironment(
    'SCREEN_PROTECTION_ENABLED',
    defaultValue: 'auto',
  );

  /// When true, [SecureScreen] enables OS-level capture blocking on mobile.
  static bool get isProtectionEnabled {
    switch (enabledFlag.toLowerCase()) {
      case 'false':
      case 'off':
        return false;
      case 'true':
      case 'on':
        return true;
      default:
        return _autoEnabled;
    }
  }

  static bool get _autoEnabled {
    if (kIsWeb) return false;
    if (kDebugMode && EnvConfig.isDev) return false;
    return true;
  }
}
