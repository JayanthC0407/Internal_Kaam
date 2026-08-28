import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Device metadata payload for OBDX `mobileClient` registration.
class MobileDevicePayload {
  const MobileDevicePayload({
    required this.osVersion,
    required this.os,
    required this.manufacturer,
    required this.model,
  });

  final String osVersion;
  final String os;
  final String manufacturer;
  final String model;
}

class MobileDeviceInfoService {
  MobileDeviceInfoService._();

  static final MobileDeviceInfoService instance = MobileDeviceInfoService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<MobileDevicePayload> collect() async {
    if (kIsWeb) {
      return const MobileDevicePayload(
        osVersion: 'unknown',
        os: 'WEB',
        manufacturer: 'unknown',
        model: 'unknown',
      );
    }

    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return MobileDevicePayload(
        osVersion: info.version.release,
        os: 'ANDROID',
        manufacturer: info.manufacturer,
        model: info.model,
      );
    }

    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return MobileDevicePayload(
        osVersion: info.systemVersion,
        os: 'IOS',
        manufacturer: 'Apple',
        model: info.model,
      );
    }

    return const MobileDevicePayload(
      osVersion: 'unknown',
      os: 'UNKNOWN',
      manufacturer: 'unknown',
      model: 'unknown',
    );
  }
}
