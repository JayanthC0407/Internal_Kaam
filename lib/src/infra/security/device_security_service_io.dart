import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:ubci_bank/src/core/config/device_security_config.dart';
import 'package:ubci_bank/src/core/constants/adlog.dart';
import 'package:ubci_bank/src/infra/security/device_security_models.dart';

class DeviceSecurityService {
  DeviceSecurityService._();

  static final DeviceSecurityService instance = DeviceSecurityService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<DeviceSecurityAssessment> evaluate() async {
    final mode = DeviceSecurityConfig.mode;
    if (mode == DeviceSecurityMode.off) {
      return DeviceSecurityAssessment.secure;
    }

    final compromised = await _isCompromisedDevice();
    if (compromised) {
      adLog('Device integrity check: compromised device detected');
      return _resultForThreat(DeviceThreatType.compromisedDevice, mode);
    }

    if (DeviceSecurityConfig.blockEmulatorInRelease && kReleaseMode) {
      final emulator = await _isEmulatorOrSimulator();
      if (emulator) {
        adLog('Device integrity check: emulator/simulator detected');
        return _resultForThreat(DeviceThreatType.emulator, mode);
      }
    }

    return DeviceSecurityAssessment.secure;
  }

  Future<bool> _isCompromisedDevice() async {
    try {
      final jailbroken = await FlutterJailbreakDetection.jailbroken;
      final developerMode = await FlutterJailbreakDetection.developerMode;
      return jailbroken || developerMode;
    } catch (error) {
      adLog('Device integrity check failed: ${error.runtimeType}');
      return false;
    }
  }

  Future<bool> _isEmulatorOrSimulator() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return !info.isPhysicalDevice;
      }
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return !info.isPhysicalDevice;
      }
    } catch (error) {
      adLog('Emulator check failed: ${error.runtimeType}');
    }
    return false;
  }

  DeviceSecurityAssessment _resultForThreat(
    DeviceThreatType threat,
    DeviceSecurityMode mode,
  ) {
    switch (mode) {
      case DeviceSecurityMode.off:
        return DeviceSecurityAssessment.secure;
      case DeviceSecurityMode.warn:
        return DeviceSecurityAssessment(
          threatType: threat,
          shouldBlock: false,
          shouldWarn: true,
        );
      case DeviceSecurityMode.block:
        return DeviceSecurityAssessment(
          threatType: threat,
          shouldBlock: true,
          shouldWarn: false,
        );
    }
  }
}
