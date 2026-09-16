import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/corp/corp_bank_configuration.dart';
import 'package:ubci_bank/src/core/models/corp/corp_party.dart';
import 'package:ubci_bank/src/core/models/corp/corp_user_profile.dart';
import 'package:ubci_bank/src/core/utils/user_type_resolver.dart';

/// The real `GET /digx-common/user/v1/me` response for the corporate user
/// in the "LOGIN to DASHBOARD" capture (entry #5), wrapped in the
/// `{ statusCode, headers, body }` envelope the login trace stores.
Map<String, dynamic> _capturedMeResponse() => {
      'statusCode': 200,
      'headers': <String, dynamic>{},
      'body': {
        'status': {'result': 'SUCCESSFUL', 'apiType': 'user'},
        'userProfile': {
          'userName': 'nazcorp',
          'firstName': 'Pooja',
          'middleName': '',
          'lastName': 'Jha',
          'partyId': {
            'displayValue': '***401',
            'value': 'C43E3BFA81256601002CD05D1678F2CD4099827FA144',
          },
          'roles': ['corporateuser', 'Maker'],
          'lastLoginTime': '2026-09-16T11:53:00.000Z',
          'emailId': {'displayValue': 'naz****d@profinch.com'},
          'phoneNumber': {'displayValue': '9898****98'},
          'groupCorporateId': '000251',
          'homeEntity': 'OBDX_BU',
          'accessibleEntities': ['OBDX_BU'],
          'accessibleEntityDTOs': [
            {
              'entityId': 'OBDX_BU',
              'entityName': 'Default Business Unit',
              'partyName': 'LC TEST4',
            },
          ],
          'corpAdmin': false,
        },
        'dashboardResponse': {
          'resolutionLevel': 'CUSTOM',
          'dashboardDTOs': [
            {
              'enterpriseRole': 'corporateuser',
              'dashboardId': '25801',
              'dashboardClass': 'CUSTOM',
              'dashboardClassValue': 'custom',
              'factory': false,
            },
            {
              'enterpriseRole': 'corporateuser',
              'dashboardId': '18',
              'dashboardClass': 'USER_TYPE',
              'dashboardClassValue': 'corporateuser',
              'factory': true,
            },
          ],
        },
        'menuSupported': true,
        'inactiveSessionTimeout': 600000,
      },
    };

void main() {
  group('CorpUserProfile', () {
    test('parses the captured corporate me response', () {
      final profile = CorpUserProfile.fromProfileResponse(
        _capturedMeResponse(),
      );

      expect(profile, isNotNull);
      expect(profile!.userName, 'nazcorp');
      expect(profile.fullName, 'Pooja Jha');
      expect(profile.initials, 'PJ');
      expect(
        profile.partyId,
        'C43E3BFA81256601002CD05D1678F2CD4099827FA144',
      );
      expect(profile.partyIdDisplay, '***401');
      // Entity name is taken from the DTO matching `homeEntity`.
      expect(profile.partyName, 'LC TEST4');
      expect(profile.roles, ['corporateuser', 'Maker']);
      expect(profile.groupCorporateId, '000251');
      expect(profile.emailDisplay, 'naz****d@profinch.com');
      expect(profile.inactiveSessionTimeoutMs, 600000);
      expect(profile.isCorpAdmin, isFalse);
      expect(profile.isMaker, isTrue);
      expect(profile.isChecker, isFalse);
    });

    test('accepts an already-unwrapped body', () {
      final body =
          _capturedMeResponse()['body'] as Map<String, dynamic>;
      expect(CorpUserProfile.fromProfileResponse(body)?.userName, 'nazcorp');
    });

    test('returns null for an unusable payload', () {
      expect(CorpUserProfile.fromProfileResponse(null), isNull);
      expect(CorpUserProfile.fromProfileResponse('not a map'), isNull);
      expect(
        CorpUserProfile.fromProfileResponse({'body': {'userProfile': {}}}),
        isNull,
      );
    });
  });

  group('resolveUserType against the captured corporate me response', () {
    test('skips the CUSTOM dashboard and resolves corporateuser', () {
      // dashboardDTOs[0] is the CUSTOM dashboard, whose class value
      // ("custom") is not one of the user's roles — taking index 0 would
      // pick the wrong dashboard.
      expect(
        resolveUserType(_capturedMeResponse()),
        UserType.corporate,
      );
    });
  });

  group('CorpParty', () {
    test('parses the captured me/party response', () {
      final party = CorpParty.fromPayload({
        'statusCode': 200,
        'body': {
          'status': {'result': 'SUCCESSFUL', 'apiType': 'user'},
          'party': {
            'id': {
              'displayValue': '***401',
              'value': 'C43E3BFA81256601002CD05D1678F2CD4099827FA144',
            },
            'personalDetails': {
              'fullName': 'LC TEST4',
              'partyType': 'IND',
            },
            'addresses': [
              {
                'addressId': '23157',
                'type': 'PST',
                'postalAddress': {'line1': 'LC TEST4', 'country': 'GB'},
              },
              {'addressId': '23158', 'type': 'RES'},
            ],
            'fatcaCheckRequired': false,
          },
        },
      });

      expect(party, isNotNull);
      expect(party!.id, 'C43E3BFA81256601002CD05D1678F2CD4099827FA144');
      expect(party.idDisplay, '***401');
      expect(party.fullName, 'LC TEST4');
      expect(party.partyType, 'IND');
      expect(party.country, 'GB');
      expect(party.fatcaCheckRequired, isFalse);
    });

    test('returns null when there is no party block', () {
      expect(CorpParty.fromPayload({'body': {}}), isNull);
    });
  });

  group('CorpBankConfiguration', () {
    test('parses the captured bankConfiguration response', () {
      final config = CorpBankConfiguration.fromPayload({
        'statusCode': 200,
        'body': {
          'status': {'result': 'SUCCESSFUL', 'apiType': 'common'},
          'bankConfigurationDTO': {
            'homeBranch': '000',
            'calCurrency': 'GBP',
            'bankCode': '000',
            'region': 'UK',
            'localCurrency': 'GBP',
            'moduleList': ['CON', 'RD'],
            'accountUniqueness': 'SYSTEM',
          },
        },
      });

      expect(config.calculationCurrency, 'GBP');
      expect(config.totalsCurrency, 'GBP');
      expect(config.region, 'UK');
      expect(config.moduleList, ['CON', 'RD']);
      expect(config.supportsModule('con'), isTrue);
      expect(config.supportsModule('ISL'), isFalse);
    });

    test('falls back to empty for a malformed payload', () {
      expect(
        CorpBankConfiguration.fromPayload({'body': {}}).totalsCurrency,
        isNull,
      );
    });
  });
}
