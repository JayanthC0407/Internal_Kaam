import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/infra/security/alternate_login_crypto.dart';

void main() {
  test('encrypt/decrypt round-trips with correct secret', () {
    const plaintext = 'jwtoken-example-value';
    const secret = '123456';
    final payload = AlternateLoginCrypto.encrypt(
      plaintext: plaintext,
      secret: secret,
    );
    expect(payload, isNot(plaintext));
    expect(
      AlternateLoginCrypto.decrypt(payload: payload, secret: secret),
      plaintext,
    );
  });

  test('decrypt fails with wrong secret', () {
    final payload = AlternateLoginCrypto.encrypt(
      plaintext: 'token',
      secret: '111111',
    );
    expect(
      AlternateLoginCrypto.decrypt(payload: payload, secret: '222222'),
      isNull,
    );
  });

  test('patternSecret joins indices', () {
    expect(AlternateLoginCrypto.patternSecret([0, 1, 4, 7]), '0-1-4-7');
  });
}
