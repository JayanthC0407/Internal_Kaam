import 'package:flutter_test/flutter_test.dart';
import 'package:demo_bank/src/infra/network/mobile_user_agent.dart';
import 'package:demo_bank/src/infra/security/mobile_device_info_service.dart';

void main() {
  test('Android: the device OS and model, marked obdx-mobile, no desktop OS', () {
    final ua = MobileUserAgent.forDevice(
      const MobileDevicePayload(osVersion: '14', os: 'ANDROID', manufacturer: 'samsung', model: 'SM-S918B'),
    );
    expect(ua, contains('(Linux; Android 14; SM-S918B)'));
    expect(ua, contains('Mobile Safari'));
    expect(ua, endsWith(' obdx-mobile'));
    expect(ua, isNot(contains('Macintosh')));
    expect(ua, isNot(contains('Windows')));
  });

  test('iOS: iPhone and iPad as WebKit sends them, marked obdx-mobile', () {
    final phone = MobileUserAgent.forDevice(
      const MobileDevicePayload(osVersion: '17.4.1', os: 'IOS', manufacturer: 'Apple', model: 'iPhone'),
    );
    expect(phone, contains('(iPhone; CPU iPhone OS 17_4_1 like Mac OS X)'));
    expect(phone, endsWith(' obdx-mobile'));
    final pad = MobileUserAgent.forDevice(
      const MobileDevicePayload(osVersion: '17.0', os: 'IOS', manufacturer: 'Apple', model: 'iPad'),
    );
    expect(pad, contains('(iPad; CPU OS 17_0 like Mac OS X)'));
  });

  test('device text cannot break the header', () {
    final ua = MobileUserAgent.forDevice(
      const MobileDevicePayload(osVersion: '13', os: 'ANDROID', manufacturer: 'x', model: 'Pixel (7);\r\nX-Evil: 1'),
    );
    expect(ua, isNot(contains('\n')));
    expect(ua, contains('Android 13; Pixel 7 X-Evil: 1)'));
  });
}
