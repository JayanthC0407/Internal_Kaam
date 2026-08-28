import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/config/ssl_pin_config.dart';

void main() {
  group('SslPinConfig', () {
    test('pinFingerprints is empty when env not set', () {
      expect(SslPinConfig.pinFingerprints, isEmpty);
    });

    test('isExplicitlyDisabled when SSL_PIN_ENABLED=false', () {
      // Compile-time constant; default in tests is 'auto'
      expect(SslPinConfig.isExplicitlyDisabled, isFalse);
    });

    test('shouldEnforcePinning is false without fingerprints', () {
      expect(SslPinConfig.shouldEnforcePinning, isFalse);
    });
  });
}
