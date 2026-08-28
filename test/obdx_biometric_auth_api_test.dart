import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_auth_api.dart';

void main() {
  group('ObdxAuthApi.extractBiometricSetupToken', () {
    test('reads jwtoken field', () {
      expect(
        ObdxAuthApi.extractBiometricSetupToken({'jwtoken': 'abc123'}),
        'abc123',
      );
    });

    test('falls back to jwtToken', () {
      expect(
        ObdxAuthApi.extractBiometricSetupToken({'jwtToken': 'xyz'}),
        'xyz',
      );
    });

    test('returns empty when missing', () {
      expect(ObdxAuthApi.extractBiometricSetupToken({}), '');
    });
  });
}
