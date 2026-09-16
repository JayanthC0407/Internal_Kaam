// Local design-review harness for the Corporate dashboard.
//
// Renders [CorpDashboardScreen] with the corporate repositories replaced by
// fakes that return the exact payloads captured in the "LOGIN to DASHBOARD"
// HAR, so the layout can be checked without a live host or a login:
//
//   flutter run -d web-server --web-port 8080 -t tool/corp_dashboard_preview.dart
//
// Not part of the app — nothing under lib/ imports this.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/models/corp/corp_bank_configuration.dart';
import 'package:ubci_bank/src/core/models/corp/corp_party.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_accounts_api.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_profile_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_accounts_repository.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_profile_repository.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_repository_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_dashboard_screen.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        corpAccountsRepositoryProvider.overrideWithValue(_FakeAccountsRepo()),
        corpProfileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
      ],
      child: const _PreviewApp(),
    ),
  );
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: LocaleConfig.supportedLocales,
      home: CorpDashboardScreen(
        args: CorpDashboardArgs(
          userName: 'nazcorp',
          loginTrace: {'profileResponse': _capturedMeResponse},
        ),
      ),
    );
  }
}

class _FakeAccountsRepo extends CorpAccountsRepository {
  _FakeAccountsRepo() : super(accountsApi: ObdxCorpAccountsApi());

  @override
  Future<ResponseHandler<CorpAccountsSummary>> fetchAccounts() async {
    return ResponseHandler.success(
      CorpAccountsSummary.fromPayload(_capturedAccountsResponse),
      code: 200,
    );
  }

  @override
  Future<ResponseHandler<List<CorpAccount>>> fetchDeposits() async =>
      ResponseHandler.success(const [], code: 200);

  @override
  Future<ResponseHandler<List<CorpAccount>>> fetchLoans() async =>
      ResponseHandler.success(const [], code: 200);
}

class _FakeProfileRepo extends CorpProfileRepository {
  _FakeProfileRepo() : super(profileApi: ObdxCorpProfileApi());

  @override
  Future<ResponseHandler<CorpParty>> fetchParty() async =>
      ResponseHandler.success(
        CorpParty.fromPayload(_capturedPartyResponse),
        code: 200,
      );

  @override
  Future<ResponseHandler<CorpBankConfiguration>>
      fetchBankConfiguration() async => ResponseHandler.success(
            CorpBankConfiguration.fromPayload(_capturedBankConfiguration),
            code: 200,
          );

  @override
  Future<ResponseHandler<int>> fetchUnreadMessageCount() async =>
      ResponseHandler.success(3, code: 200);
}

// ── Captured payloads (HAR entries #5, #7, #12, #68) ────────────────────

const _capturedMeResponse = {
  'statusCode': 200,
  'body': {
    'status': {'result': 'SUCCESSFUL', 'apiType': 'user'},
    'userProfile': {
      'userName': 'nazcorp',
      'firstName': 'Pooja',
      'lastName': 'Jha',
      'partyId': {
        'displayValue': '***401',
        'value': 'C43E3BFA81256601002CD05D1678F2CD4099827FA144',
      },
      'roles': ['corporateuser', 'Maker'],
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
      'dashboardDTOs': [
        {'dashboardClass': 'CUSTOM', 'dashboardClassValue': 'custom'},
        {'dashboardClass': 'USER_TYPE', 'dashboardClassValue': 'corporateuser'},
      ],
    },
    'inactiveSessionTimeout': 600000,
  },
};

const _capturedPartyResponse = {
  'party': {
    'id': {
      'displayValue': '***401',
      'value': 'C43E3BFA81256601002CD05D1678F2CD4099827FA144',
    },
    'personalDetails': {'fullName': 'LC TEST4', 'partyType': 'IND'},
    'addresses': [
      {
        'type': 'PST',
        'postalAddress': {'line1': 'LC TEST4', 'country': 'GB'},
      },
    ],
  },
};

const _capturedBankConfiguration = {
  'bankConfigurationDTO': {
    'homeBranch': '000',
    'calCurrency': 'GBP',
    'bankCode': '000',
    'region': 'UK',
    'localCurrency': 'GBP',
    'moduleList': ['CON', 'RD'],
  },
};

const _capturedAccountsResponse = {
  'status': {'result': 'SUCCESSFUL', 'apiType': 'account'},
  'accounts': [
    {
      'id': {
        'displayValue': 'xxxxxxxxxxxx1022',
        'value': 'CASA-1022',
      },
      'partyId': {'displayValue': '***401', 'value': 'PARTY-401'},
      'displayName': 'LC TEST4',
      'status': 'ACTIVE',
      'type': 'CSA',
      'currencyCode': 'AED',
      'branchCode': '006',
      'productDTO': {
        'description': 'Current Accounts - Regular',
        'productId': 'CACCA',
      },
      'partyName': 'LC TEST4',
      'module': 'CON',
      'defaultAccount': false,
      'ddaAccountType': 'CURRENT',
      'availableBalance': {'currency': 'AED', 'amount': -1000},
      'currentBalance': {'currency': 'AED', 'amount': -1000},
      'equivalentAvailableBalance': {'currency': 'GBP', 'amount': -272.479},
    },
    {
      'id': {
        'displayValue': 'xxxxxxxxxxxx1033',
        'value': 'CASA-1033',
      },
      'partyId': {'displayValue': '***401', 'value': 'PARTY-401'},
      'displayName': 'LC TEST4',
      'status': 'ACTIVE',
      'type': 'CSA',
      'currencyCode': 'AED',
      'productDTO': {
        'description': 'Savings Account - Regular',
        'productId': 'SAVIN',
      },
      'partyName': 'LC TEST4',
      'module': 'CON',
      'defaultAccount': true,
      'ddaAccountType': 'SAVING',
      'availableBalance': {'currency': 'AED', 'amount': 1049601.58},
      'currentBalance': {'currency': 'AED', 'amount': 1049601.58},
    },
    {
      'id': {
        'displayValue': 'xxxxxxxxxxxx1044',
        'value': 'CASA-1044',
      },
      'partyId': {'displayValue': '***401', 'value': 'PARTY-401'},
      'displayName': 'LC TEST4',
      'status': 'ACTIVE',
      'type': 'CSA',
      'currencyCode': 'GBP',
      'productDTO': {
        'description': 'Savings Account - Regular',
        'productId': 'SAVIN',
      },
      'partyName': 'LC TEST4',
      'module': 'CON',
      'defaultAccount': false,
      'ddaAccountType': 'SAVING',
      'availableBalance': {'currency': 'GBP', 'amount': 100000},
      'currentBalance': {'currency': 'GBP', 'amount': 100000},
    },
  ],
  'summary': {
    'items': [
      {
        'accountType': 'CSA',
        'partyName': 'LC TEST4',
        'count': 3,
        'totalAvailableBalance': {'currency': 'GBP', 'amount': 385721.909},
        'totalActiveAvailableBalance': {'currency': 'GBP', 'amount': 385994.388},
      },
      {'accountType': 'TRD', 'count': 0},
      {'accountType': 'LON', 'count': 0},
    ],
  },
};
