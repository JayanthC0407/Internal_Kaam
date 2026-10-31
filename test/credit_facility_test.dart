import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/corp/credit_facility_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_credit_facility_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_credit_facility_repository.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_credit_facility_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_menu.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/facility_details_page.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/facility_summary_page.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_nav_content.dart';

// Shapes follow OBDX credit-facility components and the design-dashboard
// samples (docs/obdx/features/credit-facility.md). Values are made up.

Map<String, dynamic> _money(num a) => {'amount': a, 'currency': 'USD'};

Map<String, dynamic> _facility(String code, String serial,
        {String main = '', num limit = 1000, num used = 250, bool revolving = false, String? expiry, List<Map<String, dynamic>> children = const []}) =>
    {
      'lineCode': code,
      'lineSerialNumber': serial,
      'mainLineCode': main,
      'category': 'AR FINANCE',
      'categoryDesc': 'Ar Finance',
      'revolvingLine': revolving,
      'status': 'ACTIVE',
      'currencyCode': 'USD',
      'limitAmount': _money(limit),
      'effectiveAmount': _money(limit),
      'utilizedAmount': _money(used),
      'availableAmount': _money(limit - used),
      'partyId': {'value': 'P1', 'displayValue': '***P1'},
      if (expiry != null) 'expiryDate': expiry,
      'childFacilities': children,
    };

final _payload = {
  'facilitydtos': [
    _facility('MAIN1', '1', revolving: true, expiry: '2026-11-20T00:00:00', children: [
      _facility('SUB1', '1', main: 'MAIN1', limit: 400, used: 100),
    ]),
    for (var i = 2; i <= 6; i++) _facility('MAIN$i', '1'),
  ],
};

final _detail = {
  'facilityDTO': {
    ..._facility('MAIN1', '1', revolving: true),
    'blockAmount': _money(10),
    'collateralAmount': _money(900),
    'facilityType': 'TERM',
    'scheduleDetails': [
      {'limitDate': '2026-01-01T00:00:00', 'limitAmount': _money(500)},
    ],
    'covenantDTO': [
      {'covenantName': 'COV-7', 'revisionDate': '2026-05-01T00:00:00'},
    ],
    'collateralPool': [
      {'poolPercentage': 50, 'collateralGroupDTO': {'poolId': 'POOL9'}},
    ],
  },
};

final _group = {
  'collateralGroupDTO': {
    'poolId': 'POOL9',
    'groupAmount': _money(1000),
    'groupUtilizedAmount': _money(200),
    'groupBlockAmount': _money(50),
    'availableAmount': _money(600),
    'sharedCollateral': [
      {
        'allocatedGroupContributionInPercentage': 40,
        'collateralDetails': {'collateralCode': 'COL1', 'collateralDesc': 'Warehouse', 'utilizationAmount': _money(120)},
      },
    ],
  },
};

final _collaterals = {
  'collateraldtos': [
    {
      'collateralCode': 'COL1',
      'collateralValue': _money(800),
      'limitContribution': _money(700),
      'endDate': '2027-01-01T00:00:00',
      'lendableMargin': 80,
    },
  ],
};

ResponseHandler<Map<String, dynamic>> _ok(Map<String, dynamic> body) =>
    ResponseHandler.success({'statusCode': 200, 'headers': <String, dynamic>{}, 'rawBody': jsonEncode(body), 'body': body});

class _FakeApi implements ObdxCorpCreditFacilityApi {
  final calls = <String>[];

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchLiabilities({String? partyId}) async {
    calls.add('liabilities partyId=$partyId');
    return _ok({
      'liabilitydtos': [
        {'id': 'L1', 'branch': 'B01'},
        {'id': 'L2', 'branch': 'B02'},
      ],
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchFacilities(String liabilityId,
      {required String partyId, String? branchCode, String currencyCode = 'INR'}) async {
    calls.add('facilities $liabilityId partyId=$partyId branch=$branchCode currency=$currencyCode');
    return _ok(_payload);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchFacility(String liabilityId, String facilityKey) async {
    calls.add('facility $liabilityId $facilityKey');
    return _ok(_detail);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchCollaterals(String liabilityId,
      {required String partyId, String? branchCode, String currencyCode = 'INR'}) async {
    calls.add('collaterals $liabilityId partyId=$partyId currency=$currencyCode');
    return _ok(_collaterals);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchCollateralGroup(String liabilityId, String poolId) async {
    calls.add('group $liabilityId $poolId');
    return _ok(_group);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchUtilization(String liabilityId, String facilityKey,
      {String? fromDate, String? toDate}) async {
    calls.add('utilization $facilityKey from=$fromDate to=$toDate');
    return _ok({
      'historyDetails': [
        {'utilizationDate': '2026-10-01T00:00:00', 'userRefNo': 'REF1', 'transactionType': 'DRAWDOWN', 'amount': _money(100), 'availableAmount': _money(900)},
        {'utilizationDate': '2026-10-05T00:00:00', 'transactionType': 'REPAYMENT', 'amount': _money(0), 'availableAmount': _money(950)},
      ],
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('model', () {
    test('facilities: tree, key, main / sub line, utilized %, flatten, main line', () {
      final roots = CfFacility.listFromPayload(_payload);
      expect(roots.length, 6);
      final main = roots.first;
      expect(main.key, 'MAIN1_1');
      expect(main.isMainLine, isTrue);
      expect(main.children.single.isMainLine, isFalse);
      expect(main.utilizedPercent, 25);
      expect(CfFacility.flatten(roots).map((f) => f.key).take(3), ['MAIN1_1', 'SUB1_1', 'MAIN2_1']);
      expect(CfFacility.mainLineOf(roots, 'SUB1_1')!.key, 'MAIN1_1');
      expect(const CfFacility(lineCode: 'X', lineSerialNumber: '1').utilizedPercent, 0, reason: 'no sanctioned amount');
    });

    test('filter: OBDX client-side rules', () {
      final all = CfFacility.flatten(CfFacility.listFromPayload(_payload));
      final today = DateTime(2026, 10, 31);
      expect(const CfFilter(lineCode: 'main1').apply(all, today).single.key, 'MAIN1_1');
      expect(const CfFilter(revolving: true).apply(all, today).single.key, 'MAIN1_1');
      expect(const CfFilter(expiry: CfExpiry.days30).apply(all, today).single.key, 'MAIN1_1', reason: '20 days away');
      expect(const CfFilter(expiry: CfExpiry.days15).apply(all, today), isEmpty);
      expect(const CfFilter(expiry: CfExpiry.noExpiry).apply(all, today).length, 6);
      expect(const CfFilter(minAvailable: 400, maxAvailable: 800).apply(all, today).length, 6, reason: 'available 750 each');
      expect(const CfFilter(minAvailable: 760).apply(all, today), isEmpty);
      expect(CfFilter.none.apply(all, today, partyId: 'OTHER'), isEmpty, reason: 'selected party filters too');
      expect(const CfFilter(category: 'ar finance', currency: 'USD').count, 2);
    });

    test('collateral group: OBDX sums and linked collaterals from the list', () {
      final g = CfCollateralGroup.fromPayload(_group, CfCollateral.listFromPayload(_collaterals))!;
      expect(g.shownUtilized, 250);
      expect(g.shownBlock, 1000 - (200 + 50 + 600));
      expect(g.contribution(50), 500);
      final c = g.linked.single;
      expect(c.value!.amount, 800);
      expect(c.limitContribution!.amount, 700);
      expect(c.lendableMargin, 80);
      expect(c.contributionPercent, 40);
    });

    test('parties and currencies', () {
      final own = CfParty.own({
        'party': {
          'id': {'value': 'P1', 'displayValue': '***P1'},
          'personalDetails': {'fullName': 'Acme Ltd'},
        },
      })!;
      expect(own.label, 'Acme Ltd|***P1');
      final related = CfParty.related({
        'partyToPartyRelationship': [
          {'relatedParty': {'value': 'P2', 'displayValue': '***P2'}, 'relatedPartyName': 'Acme Exports'},
        ],
      });
      expect(related.single.label, 'Acme Exports|***P2');
      expect(CfLookups.currenciesFrom({'currencyList': [{'code': 'USD'}, {'code': 'INR'}]}), ['USD', 'INR']);
    });
  });

  group('repository (sent as OBDX sends it)', () {
    test('summary: partyId as given (empty first), first liability, INR', () async {
      final api = _FakeApi();
      final r = await CorpCreditFacilityRepository(api: api).fetchFacilities('');
      expect((r as Success<CfFacilities>).data!.all.length, 7);
      expect(api.calls, ['liabilities partyId=', 'facilities L1 partyId= branch=B01 currency=INR']);
    });

    test('details: facility by key; group with the user party collaterals', () async {
      final api = _FakeApi();
      final repo = CorpCreditFacilityRepository(api: api);
      final f = await repo.fetchFacility('MAIN1_1');
      expect((f as Success<CfFacility>).data!.poolId, 'POOL9');
      final g = await repo.fetchCollateralGroup('POOL9', 'P1');
      expect((g as Success<CfCollateralGroup?>).data!.linked.single.code, 'COL1');
      expect(api.calls, contains('facility L1 MAIN1_1'));
      expect(api.calls, contains('collaterals L1 partyId=P1 currency=INR'));
      final u = await repo.fetchUtilization('MAIN1_1', from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31));
      expect((u as Success<List<CfUtilizationRow>>).data!.length, 2);
      expect(api.calls.last, 'utilization MAIN1_1 from=2026-10-01 to=2026-10-31');
    });
  });

  group('menu', () {
    test('Credit Facility Management ▸ Credit Facility ▸ pages; hidden without rights', () {
      const lc = LcPermissions(viewImport: true, viewExport: true, initiate: true, amend: true);
      final item = CorpNavDestination.navItems(lc).firstWhere((i) => i.id == 'creditFacility');
      expect(item.label, 'Credit Facility Management');
      expect([for (final c in item.children.single.children) c.label], ['Facility Summary', 'Facility Details']);
      expect(CorpNavDestination.cfPageFromNavId(CorpNavDestination.navIdForCfPage(CfPage.facilityDetails)), CfPage.facilityDetails);
      final none = CorpNavDestination.navItems(lc,
          cfPermissions: const CfPermissions(facilitySummary: false, facilityDetails: false));
      expect(none.any((i) => i.id == 'creditFacility'), isFalse);
    });
  });

  group('screens', () {
    Future<_FakeApi> pump(WidgetTester tester, Widget child, {double width = 390}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _FakeApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            corpCreditFacilityRepositoryProvider.overrideWithValue(CorpCreditFacilityRepository(api: api)),
            cfPermissionsProvider.overrideWithValue(const CfPermissions()),
            cfUserPartyIdProvider.overrideWithValue('P1'),
            cfLookupsProvider.overrideWith((ref) async => const CfLookups(
                  parties: [CfParty(id: 'P1', display: '***P1', name: 'Acme Ltd')],
                  currencies: ['USD'],
                  groupCorporate: 'GC1 | Acme Group',
                )),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('summary (phone): cards, Load More, kebab, hierarchy', (tester) async {
      (String, CfDetailTab?)? opened;
      await pump(tester, FacilitySummaryPage(onOpen: (k, t) => opened = (k, t)));
      expect(find.text('GC1 | Acme Group'), findsOneWidget);
      expect(find.text('Main line'), findsNWidgets(4), reason: 'first 5 of 7: MAIN1, SUB1, MAIN2-4');
      expect(find.text('Sub Line'), findsOneWidget);
      expect(find.text('25 % Utilized'), findsWidgets);
      expect(find.text('(Showing 5 out of 7 items)'), findsOneWidget);
      await tester.tap(find.text('Load More'));
      await tester.pumpAndSettle();
      expect(find.text('(Showing 7 out of 7 items)'), findsOneWidget);
      expect(find.text('Load More'), findsNothing);

      await tester.tap(find.text('View Hierarchy').at(1));
      await tester.pumpAndSettle();
      expect(find.text('SUB1_1 Hierarchy'), findsOneWidget);
      expect(find.text('Main Line'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Covenants'));
      await tester.pumpAndSettle();
      expect(opened, ('MAIN1_1', CfDetailTab.covenants));

      await tester.tap(find.text('MAIN2_1'));
      expect(opened, ('MAIN2_1', null));
    });

    testWidgets('summary (web): tree table, Expand All, filter', (tester) async {
      await pump(tester, FacilitySummaryPage(onOpen: (_, __) {}), width: 1280);
      await tester.tap(find.byTooltip('Facility Overview'));
      await tester.pumpAndSettle();
      expect(find.text('Line Code'), findsOneWidget);
      expect(find.text('SUB1'), findsNothing, reason: 'collapsed');
      await tester.tap(find.text('Expand All'));
      await tester.pumpAndSettle();
      expect(find.text('SUB1'), findsOneWidget);
      expect(find.text('YES'), findsOneWidget);

      await tester.tap(find.byTooltip('Summary List View'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Facility Summary Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Expiring In'), findsOneWidget);
      await tester.tap(find.text('Yes').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('(Showing 1 out of 1 items)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('details from a row: amounts, More Information, tabs', (tester) async {
      await pump(tester, FacilityDetailsPage(initialKey: 'MAIN1_1', onExit: () {}), width: 1280);
      expect(find.text('Collateral Value'), findsOneWidget);
      await tester.tap(find.text('More Information'));
      await tester.pumpAndSettle();
      expect(find.text('TERM'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget, reason: 'Status shown (blank in OBDX)');
      expect(find.text('Facility Schedule'), findsOneWidget);

      // Collateral Groups first.
      expect(find.text('POOL9'), findsOneWidget);
      await tester.tap(find.text('Linked Collateral'));
      await tester.pumpAndSettle();
      expect(find.text('Warehouse'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);

      await tester.tap(find.text('Covenants'));
      await tester.pumpAndSettle();
      expect(find.text('COV-7'), findsOneWidget);

      await tester.tap(find.text('Transaction Summary'));
      await tester.pumpAndSettle();
      expect(find.text('Reference Number'), findsOneWidget);
      expect(find.text('REF1'), findsOneWidget);
      expect(find.text('--'), findsWidgets, reason: 'zero amount and missing reference');
      expect(tester.takeException(), isNull);
    });

    testWidgets('details from the menu: Choose Facility, Proceed; Cancel exits', (tester) async {
      var exited = false;
      await pump(tester, FacilityDetailsPage(onExit: () => exited = true));
      expect(find.text('Choose Facility'), findsWidgets);
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      expect(find.text('Sanctioned Amount'), findsOneWidget);
      expect(exited, isFalse);

      await pump(tester, FacilityDetailsPage(key: const ValueKey(2), onExit: () => exited = true));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(exited, isTrue);
    });
  });
}
