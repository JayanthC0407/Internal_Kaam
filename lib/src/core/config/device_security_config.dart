import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/core/config/env_config.dart';

enum DeviceSecurityMode { off, warn, block }

/// Device integrity policy (root/jailbreak, emulator).
class DeviceSecurityConfig {
  DeviceSecurityConfig._();

  /// `off` | `warn` | `block` | `auto` (default).
  static const String modeRaw =
      String.fromEnvironment('DEVICE_SECURITY_MODE', defaultValue: 'auto');

  /// When `true`, release/profile builds block emulators/simulators.
  static const String blockEmulatorRaw = String.fromEnvironment(
    'BLOCK_EMULATOR_IN_RELEASE',
    defaultValue: 'true',
  );

  static DeviceSecurityMode get mode {
    switch (modeRaw.toLowerCase()) {
      case 'off':
        return DeviceSecurityMode.off;
      case 'warn':
        return DeviceSecurityMode.warn;
      case 'block':
        return DeviceSecurityMode.block;
      default:
        return _autoMode;
    }
  }

  static DeviceSecurityMode get _autoMode {
    if (kDebugMode && EnvConfig.isDev) {
      return DeviceSecurityMode.off;
    }
    if (EnvConfig.isUat || EnvConfig.isProd || kReleaseMode) {
      return DeviceSecurityMode.block;
    }
    return DeviceSecurityMode.off;
  }

  static bool get blockEmulatorInRelease => blockEmulatorRaw.toLowerCase() != 'false';
}
