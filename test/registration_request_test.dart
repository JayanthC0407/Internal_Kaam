import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/registration_flow_result.dart';
import 'package:ubci_bank/src/core/models/registration_request.dart';

void main() {
  test('RegistrationRequest maps digx-ui lookup fields', () {
    const request = RegistrationRequest(
      firstName: 'DEMO',
      lastName: 'CUSTOMER',
      emailId: 'demo@example.com',
      partyId: '000041',
      dateOfBirth: '1990-12-01',
      accountType: 'CSA',
      accountNumber: '000000041052',
      debitCardNumber: '8888 8989 8989 9898',
    );

    final json = request.toJson();

    expect(json['registrationId'], isNull);
    expect(json['firstName'], 'DEMO');
    expect(json['lastName'], 'CUSTOMER');
    expect(json['emailId'], 'demo@example.com');
    expect(json['partyId'], '000041');
    expect(json['dateOfBirth'], '1990-12-01');
    expect(json['accountType'], 'CSA');
    expect(json['accountNumber'], '000000041052');
    expect(json['debitCardNumber'], '8888898989899898');
    expect(json['username'], isNull);
    expect(json['password'], isNull);
    expect(json['phone'], {
      'areaCode': null,
      'number': null,
      'extension': null,
    });
    expect(json['userGroups'], isEmpty);
  });

  test('RegistrationStartResult parses OBDX success payload', () {
    final result = RegistrationStartResult.fromJson({
      'registrationDTO': {
        'registrationId': '1684430215443356',
        'customer': false,
      },
      'partyVerificationResponse': {'verificationStatus': true},
      'accountVerificationResponse': {'verificationStatus': true},
      'debitCardVerificationResponse': {'verificationStatus': true},
      'tokenValid': false,
      'attemptsLeft': 5,
    });

    expect(result.registrationId, '1684430215443356');
    expect(result.attemptsLeft, 5);
    expect(result.partyVerified, isTrue);
    expect(result.tokenValid, isFalse);
  });

  test('RegistrationAuthResult treats VER + tokenValid as verified', () {
    final result = RegistrationAuthResult.fromJson({
      'registrationDTO': {
        'registrationId': '1684430215443356',
        'customer': false,
        'registrationStatus': 'VER',
      },
      'tokenValid': true,
      'attemptsLeft': 0,
    });

    expect(result.isVerified, isTrue);
    expect(result.registrationStatus, 'VER');
    expect(result.attemptsLeft, 0);
  });

  test('RegistrationAuthResult omits attemptsLeft when API does not send it', () {
    final result = RegistrationAuthResult.fromJson({
      'registrationDTO': {
        'registrationId': '1684430215443356',
        'customer': false,
      },
      'tokenValid': false,
    });

    expect(result.isVerified, isFalse);
    expect(result.attemptsLeft, isNull);
  });

  test('RegistrationAuthResult reads attemptsLeft from registrationDTO', () {
    final result = RegistrationAuthResult.fromJson({
      'registrationDTO': {
        'registrationId': '1684430215443356',
        'attemptsLeft': 3,
      },
      'tokenValid': false,
    });

    expect(result.attemptsLeft, 3);
  });
}
