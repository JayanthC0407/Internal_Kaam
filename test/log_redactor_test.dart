import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/utils/log_redactor.dart';

void main() {
  group('LogRedactor', () {
    test('redacts bearer tokens', () {
      const input = 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.abc.def';
      final output = LogRedactor.redact(input);
      expect(output, contains('[REDACTED]'));
      expect(output, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    });

    test('redacts sensitive json fields', () {
      const input = '{"password":"Secret123","userName":"demo"}';
      final output = LogRedactor.redact(input);
      expect(output, contains('password'));
      expect(output, isNot(contains('Secret123')));
      expect(output, contains('demo'));
    });

    test('redacts cookie pairs', () {
      const input = 'secretKey=abc123; JSESSIONID=node0xyz';
      final output = LogRedactor.redact(input);
      expect(output, isNot(contains('abc123')));
      expect(output, isNot(contains('node0xyz')));
    });

    test('redacts authorization headers map', () {
      final output = LogRedactor.redactHeaders({
        'Authorization': 'Bearer token-value',
        'Content-Type': 'application/json',
        'Token_id': '1111',
      });
      expect(output['Authorization'], '[REDACTED]');
      expect(output['Token_id'], '[REDACTED]');
      expect(output['Content-Type'], 'application/json');
    });

    test('redactPayload redacts nested password fields', () {
      final output = LogRedactor.redactPayload({
        'userName': 'demo',
        'password': 'Secret123',
      });
      expect(output, contains('demo'));
      expect(output, isNot(contains('Secret123')));
      expect(output, contains('[REDACTED]'));
    });
  });
}
