import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/config/device_security_config.dart';

void main() {
  test('default mode is auto', () {
    expect(DeviceSecurityConfig.modeRaw, 'auto');
  });

  test('blockEmulatorInRelease defaults to true', () {
    expect(DeviceSecurityConfig.blockEmulatorInRelease, isTrue);
  });
}
