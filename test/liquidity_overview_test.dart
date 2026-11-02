import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/obdx_batch.dart';
import 'package:ubci_bank/src/core/models/corp/liquidity_overview_models.dart';
import 'package:ubci_bank/src/core/models/corp/lm_countries.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_liquidity_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/dashboard_repository.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_liquidity_repository.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_liquidity_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/liquidity/lm_balance_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/liquidity/lm_menu.dart';
import 'package:ubci_bank/src/view/screens/corp/liquidity/lm_overview_page.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_nav_content.dart';

// Shapes follow the OBDX widgets and design-dashboard samples
// (docs/obdx/features/liquidity-management.md §3-§8). Values are made up.

ResponseHandler<Map<String, dynamic>> _ok(Map<String, dynamic> body) =>
    ResponseHandler.success({'statusCode': 200, 'headers': <String, dynamic>{}, 'rawBody': jsonEncode(body), 'body': body});

Map<String, dynamic> _account(String no, String ccy, String branch, String country, num? balance, {bool external = false}) => {
      'accountId': {'value': no, 'displayValue': 'xxxx$no'},
      'displayName': 'Account $no',
      'branchCode': branch,
      'currencyCode': ccy,
      'country': country,
      if (balance != null) 'currentBalance': {'amount': balance, 'currency': ccy},
      'external': external,
    };

final _accounts = {
  'liquidityManagementAccounts': [
    _account('01', 'USD', 'B1', 'AUS', 1000),
    _account('02', 'USD', 'B1', 'AUS', 500, external: true),
    _account('03', 'INR', 'B2', 'IND', -500),
    _account('04', 'EUR', 'B1', 'IND', null, external: true),
    _account('05', 'GBP', 'B1', 'IND', null),
  ],
};

Map<String, dynamic> _sweep(String id, num amount, {String direction = 'OneWay'}) => {
      'structureId': id,
      'instructionDescription': 'Instruction $id',
      'valueDate': '2026-10-20T02:32:09',
      'sweepDirection': direction,
      'sweepOutAccount': {'displayValue': 'xxxx11'},
      'sweepInAccount': {'displayValue': 'xxxx22'},
      'sweepOutAmount': {'amount': amount, 'currency': 'USD'},
      'sweepInAmount': {'amount': amount * 83, 'currency': 'INR'},
      'exchangeRate': '83',
      'exceptionMessage': 'Insufficient balance',
    };

class _FakeApi implements ObdxCorpLiquidityApi {
  _FakeApi({this.missingEur = false});

  final bool missingEur;
  final calls = <String>[];
  String? batchBody;

  String _q(Map<String, String>? q) => q == null || q.isEmpty ? '' : '?${[for (final e in q.entries) '${e.key}=${e.value}'].join('&')}';

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccounts(Map<String, String> query) async {
    calls.add('accounts${_q(query)}');
    return _ok(_accounts);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchCurrencies([Map<String, String>? query]) async {
    calls.add('currencies${_q(query)}');
    return _ok({
      'items': [
        {'code': 'INR'},
        {'code': 'USD'},
      ],
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchBankConfiguration() async {
    calls.add('bankConfiguration');
    return _ok({
      'bankConfigurationDTO': {'localCurrency': 'INR'},
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchParty([Map<String, String>? query]) async {
    calls.add('party${_q(query)}');
    return _ok({
      'party': {
        'personalDetails': {'fullName': 'Acme Ltd'},
      },
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchStructures(Map<String, String> query) async {
    calls.add('structures${_q(query)}');
    return _ok({
      'structure': [
        {'id': 'ST1', 'description': 'Main pool'},
      ],
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchSweepLogs(Map<String, String> query) async {
    calls.add('sweeplogs${_q(query)}');
    return _ok({
      'sweepLogs': [for (var i = 1; i <= 6; i++) _sweep('ST$i', i * 100, direction: i.isEven ? 'TwoWay' : 'OneWay')],
    });
  }

  @override
  Future<ResponseHandler<List<int>>> downloadSweepLogs(Map<String, String> query,
      {required String media, required String mediaFormat}) async {
    calls.add('download${_q({...query, 'media': media, 'mediaFormat': mediaFormat})}');
    return ResponseHandler.success(utf8.encode('x'), code: 200);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchRates(List<ObdxBatchItem> items, {String? boundary}) async {
    batchBody = ObdxBatchEncoder.encode(items, 'B');
    calls.add('batch ${items.length}');
    Map<String, dynamic> part(int i, String branch, String ccy, num rate) => {
          'sequenceId': '$i',
          'status': 200,
          'responseObj': {
            'exchangeRateKey': {'branchCode': branch, 'ccy1Code': ccy},
            'exchangeRateDetails': [
              {'midRate': rate},
            ],
          },
        };
    return _ok({
      'batchDetailResponseDTOList': [
        part(0, 'B1', 'USD', 83),
        if (!missingEur) part(1, 'B1', 'EUR', 90),
      ],
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class _FakeDashboards implements DashboardRepository {
  _FakeDashboards([this.names]);

  final List<String>? names;

  @override
  Future<ResponseHandler<DashboardConfig>> fetchConfig({
    required String dashboardClass,
    required String dashboardClassValue,
  }) async {
    final n = names;
    if (n == null) return ResponseHandler.exceptionError();
    return ResponseHandler.success(
      DashboardConfig(
        dashboardId: '1',
        dashboardName: dashboardClassValue,
        dashboardDescription: '',
        layoutsByBreakpoint: {
          for (final b in DashboardBreakpoint.values)
            b: [for (final c in n) DashboardLayoutItem(componentName: c, module: dashboardClassValue)],
        },
      ),
      code: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

final _today = DateTime(2026, 10, 31);

void main() {
  final accounts = LmAccount.listFromPayload(_accounts);
  const rates = LmRates({'B1-USD': 83, 'B1-EUR': 90});

  group('model', () {
    test('accounts: no balance and not external is skipped; external without balance is 0', () {
      expect([for (final a in accounts) a.number], ['xxxx01', 'xxxx02', 'xxxx03', 'xxxx04']);
      expect(accounts.last.balance, 0);
      expect(accounts.last.rateKey, 'B1-EUR');
      expect(lmCurrencies({'items': [{'code': 'INR'}]}), ['INR']);
      expect(lmCurrencies({'currencyList': [{'code': 'USD'}]}), ['USD'], reason: 'the sample root');
      expect(lmCountryName('AU'), 'Australia');
      expect(lmCountryName('IND'), 'India');
      expect(lmCountryName('XX'), 'XX');
    });

    test('FX batch: one GET part per branch-currency not in the target', () {
      final parts = LmRates.requests(accounts, 'INR');
      expect([for (final p in parts) p.uri], [
        '/forex/rates?branchCode=B1&ccy1Code=USD&ccy2Code=INR',
        '/forex/rates?branchCode=B1&ccy1Code=EUR&ccy2Code=INR',
      ]);
      expect(parts.first.applicationId, 'digx-forexdeal');
      expect(LmRates.requests(accounts.where((a) => a.currency == 'INR').toList(), 'INR'), isEmpty);
    });

    test('positions: by currency, by region (converted), assets / liabilities, missing rate', () {
      final byCcy = LmCurrencyPosition.group(accounts);
      expect([for (final p in byCcy) '${p.currency} ${p.balance}'], ['USD 1500.0', 'INR -500.0', 'EUR 0.0']);
      final region = LmRegionPositions.of(accounts, rates, 'INR');
      expect(region.totals, {'AUS': 124500, 'IND': -500});
      expect(LmRegionPositions.byCurrency(accounts, 'AUS').single, (currency: 'USD', count: 2, balance: 1500.0));
      expect(LmRegionPositions.of(accounts, const LmRates({'B1-USD': 83}), 'INR').missingRate, isTrue);
      final al = LmAssetsLiabilities.of(accounts, rates, 'INR');
      expect([al.assets, al.liabilities, al.net], [124500, 500, 124000]);
      expect([for (final a in LmAssetsLiabilities.accountsFor(accounts, assets: true)) a.number],
          ['xxxx01', 'xxxx02', 'xxxx04'], reason: '>= 0, largest first');
      expect([for (final a in LmAssetsLiabilities.accountsFor(accounts, assets: false)) a.number], ['xxxx03']);
    });

    test('sweeps: top five by amount in, sweep type, windows as JavaScript setMonth', () {
      final rows = LmSweepLog.listFromPayload({
        'sweepLogs': [for (var i = 1; i <= 6; i++) _sweep('ST$i', i * 100, direction: i.isEven ? 'TwoWay' : 'OneWay')],
      });
      expect([for (final r in LmSweepLog.topFive(rows)) r.structureId], ['ST6', 'ST5', 'ST4', 'ST3', 'ST2']);
      expect(rows.first.sweepType, 'Sweep');
      expect(rows[1].sweepType, 'Reverse Sweep');
      expect(LmSweepStatus.upcoming.window(_today), (from: _today, to: DateTime(2026, 12, 1)), reason: 'Nov 31 rolls over');
      expect(LmSweepStatus.executed.window(_today), (from: DateTime(2026, 10, 1), to: _today));
      expect(lmIsoDate(_today), '2026-10-31T00:00:00');
    });

    test('layout: known names in server order; all six when none known', () {
      expect(LmOverviewWidget.fromLayout(['sweep-log', 'notification-details', 'position-by-currency']),
          [LmOverviewWidget.sweepLog, LmOverviewWidget.positionByCurrency]);
      expect(LmOverviewWidget.fromLayout(['notification-details']), LmOverviewWidget.values);
    });
  });

  group('repository (queries as OBDX sends them)', () {
    test('balances widgets', () async {
      final api = _FakeApi();
      final repo = CorpLiquidityRepository(api: api);
      await repo.fetchPositionByCurrency();
      expect(api.calls, ['party', 'accounts?isNotional=false&sortBy=null&count=null']);
      api.calls.clear();
      await repo.fetchRegionBalances();
      expect(api.calls, unorderedEquals(['accounts?isNotional=false', 'currencies', 'bankConfiguration', 'party']));
      api.calls.clear();
      final data = (await repo.fetchAssetsBalances() as Success<LmBalances>).data!;
      expect(api.calls, contains('accounts?taskCode=null&isNotional=false&isLinkedParties=null&isMultiStructure=null'
          '&q=null&sortBy=null&count=null'));
      expect(api.calls, contains('party?media=null'));
      expect(data.defaultCurrency, 'INR');
      expect(data.partyName, 'Acme Ltd');
      final r = await repo.fetchRates(data.accounts, 'INR');
      expect(r.byKey, {'B1-USD': 83, 'B1-EUR': 90});
      expect(api.batchBody, contains('GET /forex/rates?branchCode=B1&ccy1Code=USD&ccy2Code=INR HTTP/1.1'));
      expect(api.batchBody, contains('Application-Id: digx-forexdeal'));
    });

    test('sweep widgets', () async {
      final api = _FakeApi();
      final repo = CorpLiquidityRepository(api: api);
      await repo.fetchSweepCurrencies();
      await repo.fetchTopSweeps('INR', cross: true, today: _today);
      await repo.fetchTopSweeps('INR', cross: false, today: _today);
      final monitor = await repo.fetchSweepMonitor(LmSweepStatus.pending, today: _today);
      await repo.fetchStructures();
      expect((monitor as Success<List<LmSweepLog>>).data!.length, 5, reason: 'first five, server order');
      expect(api.calls, [
        'currencies?limit=null&offset=null&q=null',
        'bankConfiguration',
        'sweeplogs?structureId=null&fromDate=2026-10-01T00:00:00&toDate=2026-10-31T00:00:00&sweepStatus=S'
            '&structureType=Sweep&toAccCcy=INR&crossCcy=true',
        'sweeplogs?fromDate=2026-10-01T00:00:00&toDate=2026-10-31T00:00:00&sweepStatus=S'
            '&structureType=Sweep&toAccCcy=INR&crossCcy=false',
        'sweeplogs?structureId=null&fromDate=2026-10-01T00:00:00&toDate=2026-10-31T00:00:00&sweepStatus=P'
            '&structureType=Sweep&toAccCcy=null&crossCcy=null',
        'structures?limit=null&offset=null&structureType=null&structureStatus=null&latestDetailsRequired=null',
      ]);
    });
  });

  group('menu', () {
    const lc = LcPermissions(viewImport: true, viewExport: true, initiate: true, amend: true);

    test('Overview first, then Charges Inquiry; Overview hidden without the dashboard', () {
      final item = CorpNavDestination.navItems(lc).firstWhere((i) => i.id == 'liquidityManagement');
      expect([for (final c in item.children) c.label], ['Overview', 'Charges Inquiry']);
      expect(CorpNavDestination.lmPageFromNavId(item.children.first.id), LmPage.overview);
      final without = CorpNavDestination.navItems(lc, lmPermissions: const LmPermissions(overview: false))
          .firstWhere((i) => i.id == 'liquidityManagement');
      expect([for (final c in without.children) c.label], ['Charges Inquiry']);
    });
  });

  group('screen', () {
    Future<_FakeApi> pump(WidgetTester tester,
        {double width = 1280, List<String>? layout, bool missingEur = false}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _FakeApi(missingEur: missingEur);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            corpLiquidityRepositoryProvider.overrideWithValue(CorpLiquidityRepository(api: api)),
            dashboardRepositoryProvider.overrideWithValue(_FakeDashboards(layout)),
            lmTodayProvider.overrideWithValue(_today),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(padding: EdgeInsets.all(16), child: LmOverviewPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('web, all six (layout fails): titles, currency position dialog', (tester) async {
      await pump(tester);
      for (final title in [
        'Balances Summary',
        'Top 5 Cross Currency Sweeps',
        'Position By Currency',
        'Position By Region',
        'Sweep Monitor',
        'Top 5 Sweeps in INR',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      await tester.tap(find.descendant(of: find.byType(LmPositionByCurrency), matching: find.textContaining('1,500')));
      await tester.pumpAndSettle();
      expect(find.text('Position By Currency - USD'), findsOneWidget);
      expect(find.text('Acme Ltd'), findsNWidgets(2));
      expect(find.text('External'), findsOneWidget);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('region: converted totals, country panel, accounts by currency', (tester) async {
      await pump(tester, layout: ['position-by-region']);
      expect(find.text('Australia'), findsOneWidget);
      expect(find.textContaining('124,500'), findsOneWidget);
      await tester.tap(find.text('Australia'));
      await tester.pumpAndSettle();
      expect(find.text('Accounts'), findsOneWidget);
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(find.text('Position By Region'), findsNWidgets(2), reason: 'widget title and dialog title');
      expect(find.text('xxxx02'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('balances summary: net position; a bar opens Accounts Summary', (tester) async {
      await pump(tester, layout: ['assets-and-liabilities']);
      expect(find.text('Net Positions :'), findsOneWidget);
      expect(find.textContaining('124,000'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('^Liabilities:')));
      await tester.pumpAndSettle();
      expect(find.text('Accounts Summary'), findsOneWidget);
      expect(find.text('xxxx03'), findsOneWidget);
      expect(find.text('xxxx01'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing rate: "Exchange rate not found"', (tester) async {
      await pump(tester, layout: ['assets-and-liabilities', 'position-by-region'], missingEur: true);
      expect(find.text('Exchange rate not found'), findsNWidgets(2));
    });

    testWidgets('sweep monitor: tabs change columns; Download PDF sends the tab', (tester) async {
      final api = await pump(tester, layout: ['sweep-log']);
      expect(find.text('Source Account'), findsOneWidget);
      await tester.tap(find.text('Executed'));
      await tester.pumpAndSettle();
      expect(find.text('Sweep Type'), findsOneWidget);
      expect(find.text('Reverse Sweep'), findsWidgets);
      expect(find.text('Main pool'), findsOneWidget);
      await tester.tap(find.byTooltip('Download'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF'));
      await tester.pump();
      expect(api.calls.where((c) => c.startsWith('download')).single,
          contains('sweepStatus=S&structureType=Sweep&toAccCcy=null&crossCcy=null&media=application/pdf&mediaFormat=pdf'));
      // Saving the file needs the platform, which a test has not: the
      // spinner stays, so no pumpAndSettle here.
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('phone: stacked, cards instead of tables', (tester) async {
      await pump(tester, width: 390, layout: ['sweep-log', 'top-five-sweeps', 'cross-border-sweeps']);
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('Top 5 Sweeps in INR'), findsOneWidget);
      expect(find.text('ST6'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
