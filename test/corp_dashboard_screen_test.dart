import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/models/corp/corp_bank_configuration.dart';
import 'package:ubci_bank/src/core/models/corp/corp_currency.dart';
import 'package:ubci_bank/src/core/models/corp/corp_dashboard_config.dart';
import 'package:ubci_bank/src/core/models/corp/corp_widget_definition.dart';
import 'package:ubci_bank/src/core/models/corp/corp_pickup_point.dart';
import 'package:ubci_bank/src/core/models/corp/corp_party.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_accounts_repository.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_cash_management_repository.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_dashboard_repository.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_profile_repository.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_cash_management_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_personalization_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_repository_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_dashboard_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_personalize_dashboard_screen.dart';

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

/// The pickup-points widget owns its data, so the dashboard test has to
/// fake its repository too — otherwise building the real one constructs the
/// shared Dio client and the test would need --dart-define=OBDX_BASE_URL.
class _FakeCashManagementRepository implements CorpCashManagementRepository {
  @override
  Future<ResponseHandler<List<CorpPickupPoint>>> fetchPickupPoints({
    List<String> collectionTypes = const ['CASH', 'PAPERBASE'],
  }) async =>
      ResponseHandler.success(
        CorpPickupPoint.listFromPayload(
          const {
            'pointDetails': [
              {
                'code': 'LA',
                'serviceType': 'LA',
                'locationCode': 'CASH',
                'description': 'LA',
                'locationDescription': 'LA',
                'contactDetails': {
                  'name': 'gloria',
                  'phoneNumber': '9876543210',
                  'address1': 'LOs Angeles',
                  'country': 'India',
                },
                'scheduleDetails': {
                  'frequency': 'Daily',
                  'dayOfWeek': 'Monday',
                  'type': 'Adhoc/On Call',
                },
              },
            ],
          },
          collectionType: 'CASH',
        ),
        code: 200,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Personalization drives the dashboard body, so the dashboard test needs
/// this faked too. Returns a config whose layouts are empty, which makes
/// the dashboard fall back to its designed default arrangement — the state
/// the rest of these tests assert against. The personalized render path has
/// its own tests.
class _FakeDashboardRepository implements CorpDashboardRepository {
  _FakeDashboardRepository({this.config});

  final CorpDashboardConfig? config;

  static CorpDashboardConfig emptyConfig() =>
      CorpDashboardConfig.fromPayload(const {
        'dashboardDTO': {
          'dashboardId': '25801',
          'dashboardName': 'obdx-name',
          'dashboardDescription': 'obdx-description',
          'dashboardClass': 'CUSTOM',
          'dashboardClassValue': 'custom',
          'factory': false,
          'layout': {
            'layout': {
              'defaultLayout': [],
              'large': [],
              'medium': [],
              'small': [],
            },
          },
        },
      })!;

  @override
  Future<ResponseHandler<CorpDashboardConfig>> fetchConfig({
    required String dashboardClass,
    required String dashboardClassValue,
  }) async =>
      ResponseHandler.success(config ?? emptyConfig(), code: 200);

  @override
  Future<ResponseHandler<CorpDashboardConfig>> saveConfig(
    CorpDashboardConfig config,
  ) async =>
      ResponseHandler.success(config, code: 200);

  @override
  Future<ResponseHandler<CorpAuthorizedComponents>>
      fetchAuthorizedComponents() async => ResponseHandler.success(
            const CorpAuthorizedComponents(
              authorized: {
                'account-financial-summary',
                'account-quick-links',
                'currency-exposure',
                'pickup-point-collections',
                'account-summary',
                // Authorized but not implemented here — the case the
                // placeholder card exists for.
                'bulk-file-upload',
              },
            ),
            code: 200,
          );

  @override
  Future<CorpCatalogResult> fetchCatalog() async => CorpCatalogResult(
        catalog: CorpWidgetCatalog.fromPayload(const {
          'components': [
            {
              'componentName': 'account-financial-summary',
              'module': 'corporateDashboard',
              'segment': ['corporateuser'],
              'isVisible': true,
              'isWidget': true,
            },
            {
              'componentName': 'currency-exposure',
              'module': 'corporateDashboard',
              'segment': ['common'],
            },
          ],
        }),
        source: CorpCatalogSource.environment,
      );

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
  Future<ResponseHandler<List<CorpCurrency>>> fetchCurrencies() async =>
      ResponseHandler.success(
        CorpCurrency.listFromPayload(const {
          'currencyList': [
            {'code': 'AED', 'description': 'UAE Dirham', 'type': 'PC'},
            {'code': 'GBP', 'description': 'Pound Sterling', 'type': 'PC'},
          ],
        }),
        code: 200,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  CorpDashboardConfig? config,
}) async {
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
        corpCashManagementRepositoryProvider
            .overrideWithValue(_FakeCashManagementRepository()),
        corpDashboardRepositoryProvider
            .overrideWithValue(_FakeDashboardRepository(config: config)),
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

    testWidgets('renders every dashboard panel', (tester) async {
      await _pumpDashboard(tester);

      expect(find.text('Quick Links'), findsOneWidget);
      expect(find.text('Account Summary'), findsOneWidget);
      expect(find.text('Financial Summary'), findsOneWidget);
      expect(find.text('Currency Exposure'), findsOneWidget);
      expect(find.text('Pickup Points'), findsOneWidget);
      // Tab strip.
      expect(find.text('Accounts'), findsWidgets);
      expect(find.text('Deposits'), findsWidgets);
      expect(find.text('Loans'), findsWidgets);
    });

    testWidgets('financial summary shows the host roll-up per group',
        (tester) async {
      await _pumpDashboard(tester);

      // summary.items[] reports CSA count 2 for this payload, and zero
      // deposits / loans — the counts come from the host, not from a
      // client-side tally of the accounts array.
      expect(find.text('2 accounts'), findsWidgets);
      expect(find.text('0 accounts'), findsWidgets);
    });

    testWidgets('currency exposure groups CASA accounts by currency',
        (tester) async {
      await _pumpDashboard(tester);

      // Both CASA accounts in the payload are AED, so there is exactly one
      // exposure row, labelled from the currency master.
      expect(find.text('UAE Dirham'), findsOneWidget);
      expect(find.text('AED'), findsWidgets);
      // -1000 + 1049601.58 netted into a single position.
      expect(find.text('AED 1,048,601.58'), findsOneWidget);
    });

    testWidgets('pickup points loads its own data on mount', (tester) async {
      await _pumpDashboard(tester);

      // Proves a registry widget can own its data source: nothing in the
      // dashboard's primary load fetches this.
      expect(find.text('LA'), findsWidgets);
      expect(find.text('Daily · Monday · Adhoc/On Call'), findsOneWidget);
      expect(find.text('LOs Angeles, India'), findsOneWidget);
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

    testWidgets('settings menu offers Personalize Dashboard', (tester) async {
      await _pumpDashboard(tester);

      // The entry point: gear icon in the header.
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Personalize Dashboard'), findsOneWidget);
    });

    testWidgets('Personalize opens as a side panel, not a new page',
        (tester) async {
      await _pumpDashboard(tester);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personalize Dashboard'));
      await tester.pumpAndSettle();

      // The panel is an end drawer, so the dashboard stays mounted behind
      // it — that is what lets a save show up immediately.
      expect(find.byType(CorpPersonalizePanel), findsOneWidget);
      expect(find.text('Account Summary'), findsWidgets);
    });

    testWidgets('Quick Links renders once, not twice', (tester) async {
      // Regression: the card was hard-coded in the hero row *and*
      // registered as `account-quick-links`, so a saved layout containing
      // it drew the widget twice.
      await _pumpDashboard(
        tester,
        config: CorpDashboardConfig.fromPayload(const {
          'dashboardDTO': {
            'dashboardId': '25801',
            'dashboardName': 'obdx-name',
            'dashboardDescription': 'obdx-description',
            'layout': {
              'layout': {
                'defaultLayout': [],
                'large': [
                  {
                    'componentName': 'account-quick-links',
                    'module': 'corporateDashboard',
                    'style': 'oj-lg-4',
                  },
                ],
                'medium': [],
                'small': [],
              },
            },
          },
        }),
      );

      expect(find.text('Quick Links'), findsOneWidget);
    });

    testWidgets('renders the saved layout through the widget registry',
        (tester) async {
      // A saved configuration takes over the dashboard body below the
      // accounts hero.
      await _pumpDashboard(
        tester,
        config: CorpDashboardConfig.fromPayload(const {
          'dashboardDTO': {
            'dashboardId': '25801',
            'dashboardName': 'obdx-name',
            'dashboardDescription': 'obdx-description',
            'dashboardClass': 'CUSTOM',
            'dashboardClassValue': 'custom',
            'layout': {
              'layout': {
                'defaultLayout': [],
                'large': [
                  {
                    'componentName': 'currency-exposure',
                    'module': 'corporateDashboard',
                    'style': 'oj-lg-12',
                  },
                  {
                    'componentName': 'bulk-file-upload',
                    'module': 'corporateDashboard',
                    'style': 'oj-lg-12',
                  },
                ],
                'medium': [],
                'small': [],
              },
            },
          },
        }),
      );

      // Implemented component renders for real.
      expect(find.text('Currency Exposure'), findsOneWidget);
      // Unimplemented one renders a named placeholder rather than vanishing.
      expect(find.text('Bulk File Upload'), findsOneWidget);
      expect(find.text('Not available in this app yet'), findsOneWidget);

      // The saved layout replaced the default arrangement.
      expect(find.text('Pickup Points'), findsNothing);
    });

    testWidgets('drops a saved component the user is not authorized for',
        (tester) async {
      // `work-snapshot` is the real case: present on the captured user's
      // saved dashboard but absent from authorizedUIComponents.
      await _pumpDashboard(
        tester,
        config: CorpDashboardConfig.fromPayload(const {
          'dashboardDTO': {
            'dashboardId': '25801',
            'dashboardName': 'obdx-name',
            'dashboardDescription': 'obdx-description',
            'layout': {
              'layout': {
                'defaultLayout': [],
                'large': [
                  {
                    'componentName': 'work-snapshot',
                    'module': 'corporateDashboard',
                    'style': 'oj-lg-12',
                  },
                  {
                    'componentName': 'currency-exposure',
                    'module': 'corporateDashboard',
                    'style': 'oj-lg-12',
                  },
                ],
                'medium': [],
                'small': [],
              },
            },
          },
        }),
      );

      expect(find.text('Currency Exposure'), findsOneWidget);
      expect(find.text('Work Snapshot'), findsNothing);
    });

    testWidgets('falls back to the designed layout when nothing is saved',
        (tester) async {
      // The empty-config default: the dashboard must never be blank.
      await _pumpDashboard(tester);

      expect(find.text('Financial Summary'), findsOneWidget);
      expect(find.text('Currency Exposure'), findsOneWidget);
      expect(find.text('Pickup Points'), findsOneWidget);
      expect(find.text('Account Summary'), findsOneWidget);
      // Quick Links belongs to the default arrangement too — exactly once.
      expect(find.text('Quick Links'), findsOneWidget);
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
    'dashboardResponse': {
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
