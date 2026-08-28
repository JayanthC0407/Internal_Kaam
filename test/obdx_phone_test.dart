import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/obdx_phone.dart';

void main() {
  test('ObdxPhone.fromPlainInput uses default country code for local numbers', () {
    final phone = ObdxPhone.fromPlainInput('8571084046');

    expect(phone.countryCode, '91');
    expect(phone.areaCode, '');
    expect(phone.number, '8571084046');
    expect(phone.toJson(), {
      'countryCode': '91',
      'areaCode': '',
      'number': '8571084046',
    });
  });

  test('ObdxPhone.fromPlainInput parses international prefix', () {
    final phone = ObdxPhone.fromPlainInput('+918571084046');

    expect(phone.countryCode, '91');
    expect(phone.number, '8571084046');
  });
}
