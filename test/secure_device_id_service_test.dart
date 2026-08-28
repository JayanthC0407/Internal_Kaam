import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/infra/security/secure_device_id_service.dart';

void main() {
  group('SecureDeviceIdService', () {
    test('generated id is 16 lowercase hex characters', () {
      final service = SecureDeviceIdService.instance;
      final id = service.generateForTest();
      expect(id.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(id), isTrue);
    });
  });
}
