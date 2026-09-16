import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/models/corp/corp_bank_configuration.dart';
import 'package:ubci_bank/src/core/models/corp/corp_party.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_accounts_repository.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_profile_repository.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_repository_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_dashboard_screen.dart';

/// The fakes `implements` (rather than `extends`) the repositories on
/// purpose: extending would run the real constructor, which builds the
/// shared Dio client and so requires OBDX_BASE_URL to be defined. Tests
/// must pass without any --dart-define.
class _FakeAccountsRepository implements CorpAccountsRepository {
  @override
  Future<ResponseHandler<CorpAccountsSummary>> fetchAccounts() async =>
      ResponseHandler.success(
        CorpAccountsSummary.fromPayload(_accountsResponse),
        code: 200,
      );

  @override
  Future<ResponseHandler<List<CorpAccount>>> fetchDeposits() async =>
      ResponseHandler.success(const [], code: 200);

  @override
  Future<ResponseHandler<List<CorpAccount>>> fetchLoans() async =>
      ResponseHandler.success(const [], code: 200);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

class _FakeProfileRepository implements CorpProfileRepository {
  @override
  Future<ResponseHandler<CorpParty>> fetchParty() async =>
      ResponseHandler.success(
        CorpParty.fromPayload(const {
          'party': {
            'id': {'displayValue': '***401', 'value': 'PARTY-401'},
            'personalDetails': {'fullName': 'LC TEST4', 'partyType': 'IND'},
          },
        }),
        code: 200,
      );

  @override
  Future<ResponseHandler<CorpBankConfiguration>>
      fetchBankConfiguration() async => ResponseHandler.success(
            CorpBankConfiguration.fromPayload(const {
              'bankConfigurationDTO': {
                'calCurrency': 'GBP',
                'localCurrency': 'GBP',
                'moduleList': ['CON', 'RD'],
              },
            }),
            code: 200,
          );

  @override
  Future<ResponseHandler<int>> fetchUnreadMessageCount() async =>
      ResponseHandler.success(3, code: 200);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

Future<void> _pumpDashboard(WidgetTester tester) async {
  // The design is a desktop layout; size the surface accordingly so the
  // persistent sidebar and the side-by-side panels are the ones exercised.
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        corpAccountsRepositoryProvider
            .overrideWithValue(_FakeAccountsRepository()),
        corpProfileRepositoryProvider
            .overrideWithValue(_FakeProfileRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleConfig.supportedLocales,
        home: CorpDashboardScreen(
          args: CorpDashboardArgs(
            userName: 'nazcorp',
            loginTrace: const {'profileResponse': _meResponse},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CorpDashboardScreen', () {
    testWidgets(
      'loads without modifying a provider during the widget life-cycle',
      (tester) async {
        // Regression test: the dashboard used to seed the profile notifier
        // from initState, which trips Riverpod's
        // "Tried to modify a provider while the widget tree was building"
        // assertion. The seed now happens in a post-frame callback.
        await _pumpDashboard(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders the three dashboard panels', (tester) async {
      await _pumpDashboard(tester);

      expect(find.text('Quick Links'), findsOneWidget);
      expect(find.text('Account Summary'), findsOneWidget);
      // Tab strip.
      expect(find.text('Accounts'), findsWidgets);
      expect(find.text('Deposits'), findsOneWidget);
      expect(find.text('Loans'), findsOneWidget);
    });

    testWidgets('fills the summary grid from the accounts payload',
        (tester) async {
      await _pumpDashboard(tester);

      // Masked account numbers, exactly as the grid displays them.
      expect(find.text('XXXX XXXX XXXX 1022'), findsOneWidget);
      expect(find.text('XXXX XXXX XXXX 1033'), findsOneWidget);

      // Product description drives the "Account Type" column.
      expect(find.text('Current Accounts - Regular'), findsOneWidget);

      // Overdrawn balance keeps its sign ahead of the currency code.
      expect(find.text('-AED 1,000.00'), findsOneWidget);
      expect(find.text('AED 1,049,601.58'), findsOneWidget);
    });

    testWidgets('seeds the header from the captured me response',
        (tester) async {
      await _pumpDashboard(tester);
      // "Pooja Jha" -> PJ, rather than the login username's initials.
      expect(find.text('PJ'), findsOneWidget);
    });

    testWidgets('shows the unread mailbox count on the bell', (tester) async {
      await _pumpDashboard(tester);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('sorting the balance column reorders the rows',
        (tester) async {
      await _pumpDashboard(tester);

      Future<double> yOf(String text) async {
        return tester.getCenter(find.text(text)).dy;
      }

      // Default sort is party name; all three rows share a party, so the
      // payload order stands and the overdrawn account is first.
      expect(await yOf('-AED 1,000.00') < await yOf('AED 1,049,601.58'), isTrue);

      await tester.tap(find.text('Balance'));
      await tester.pumpAndSettle();

      // Ascending by balance still puts the negative first...
      expect(await yOf('-AED 1,000.00') < await yOf('AED 1,049,601.58'), isTrue);

      await tester.tap(find.text('Balance'));
      await tester.pumpAndSettle();

      // ...and descending flips it.
      expect(await yOf('-AED 1,000.00') > await yOf('AED 1,049,601.58'), isTrue);
    });
  });
}

// ── Captured payloads (HAR entries #5 and #68) ──────────────────────────

const _meResponse = {
  'statusCode': 200,
  'body': {
    'status': {'result': 'SUCCESSFUL', 'apiType': 'user'},
    'userProfile': {
      'userName': 'nazcorp',
      'firstName': 'Pooja',
      'lastName': 'Jha',
      'partyId': {'displayValue': '***401', 'value': 'PARTY-401'},
      'roles': ['corporateuser', 'Maker'],
      'homeEntity': 'OBDX_BU',
      'accessibleEntityDTOs': [
        {'entityId': 'OBDX_BU', 'partyName': 'LC TEST4'},
      ],
    },
    'inactiveSessionTimeout': 600000,
  },
};

const _accountsResponse = {
  'status': {'result': 'SUCCESSFUL', 'apiType': 'account'},
  'accounts': [
    {
      'id': {'displayValue': 'xxxxxxxxxxxx1022', 'value': 'CASA-1022'},
      'partyName': 'LC TEST4',
      'status': 'ACTIVE',
      'type': 'CSA',
      'currencyCode': 'AED',
      'ddaAccountType': 'CURRENT',
      'defaultAccount': false,
      'productDTO': {'description': 'Current Accounts - Regular'},
      'availableBalance': {'currency': 'AED', 'amount': -1000},
    },
    {
      'id': {'displayValue': 'xxxxxxxxxxxx1033', 'value': 'CASA-1033'},
      'partyName': 'LC TEST4',
      'status': 'ACTIVE',
      'type': 'CSA',
      'currencyCode': 'AED',
      'ddaAccountType': 'SAVING',
      'defaultAccount': true,
      'productDTO': {'description': 'Savings Account - Regular'},
      'availableBalance': {'currency': 'AED', 'amount': 1049601.58},
    },
  ],
  'summary': {
    'items': [
      {'accountType': 'CSA', 'partyName': 'LC TEST4', 'count': 2},
      {'accountType': 'TRD', 'count': 0},
      {'accountType': 'LON', 'count': 0},
    ],
  },
};
