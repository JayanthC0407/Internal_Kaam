import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/config/screen_security_config.dart';

void main() {
  test('default screen protection flag is auto', () {
    expect(ScreenSecurityConfig.enabledFlag, 'auto');
  });
}
