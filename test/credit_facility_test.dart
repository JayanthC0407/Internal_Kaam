import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/corp/credit_facility_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_credit_facility_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/dashboard_repository.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_credit_facility_repository.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_credit_facility_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_menu.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_overview_page.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/collateral_details_page.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/collateral_summary_page.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/credit_facility_workspace.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/facility_details_page.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/facility_summary_page.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_nav_content.dart';

// Shapes follow OBDX credit-facility components and the design-dashboard
// samples (docs/obdx/features/credit-facility.md). Values are made up.

Map<String, dynamic> _money(num a) => {'amount': a, 'currency': 'USD'};

Map<String, dynamic> _inr(num a) => {'amount': a, 'currency': 'INR'};

Map<String, dynamic> _facility(String code, String serial,
        {String main = '',
        num limit = 1000,
        num used = 250,
        bool revolving = false,
        String? expiry,
        String category = 'AR FINANCE',
        List<Map<String, dynamic>> children = const []}) =>
    {
      'lineCode': code,
      'lineSerialNumber': serial,
      'mainLineCode': main,
      'category': category,
      'categoryDesc': 'Ar Finance',
      'revolvingLine': revolving,
      'status': 'ACTIVE',
      'currencyCode': 'USD',
      'limitAmount': _money(limit),
      'effectiveAmount': _money(limit),
      'utilizedAmount': _money(used),
      'availableAmount': _money(limit - used),
      'effectiveAmountInBaseCurr': _inr(limit * 80),
      'utilizedAmountInBaseCurr': _inr(used * 80),
      'availableAmountInBaseCurr': _inr((limit - used) * 80),
      'partyId': {'value': 'P1', 'displayValue': '***P1'},
      if (expiry != null) 'expiryDate': expiry,
      'childFacilities': children,
    };

final _payload = {
  'facilitydtos': [
    _facility('MAIN1', '1', revolving: true, expiry: '2026-11-20T00:00:00', children: [
      _facility('SUB1', '1', main: 'MAIN1', limit: 400, used: 100),
    ]),
    for (var i = 2; i <= 5; i++) _facility('MAIN$i', '1'),
    _facility('MAIN6', '1', category: 'TERM LOAN'),
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
      'collateralCategory': 'PROPERTY',
      'availableAmount': _money(300),
      'utilizationAmount': _money(120),
      'utilizationAmountInBaseCurr': _inr(9600),
      'availableAmountInBaseCurr': _inr(44000),
      'equivalentLimitContribution': _inr(56000),
      'equivalentBlockAmount': _inr(2400),
      'startDate': '2026-02-01T00:00:00',
    },
    {
      'collateralCode': 'COL2',
      'collateralCategory': 'VEHICLE',
      'collateralDesc': 'Truck fleet',
      'collateralValue': _money(500),
      'limitContribution': _money(400),
      'availableAmount': _money(450),
      'lendableMargin': 12.5,
      'utilizationAmountInBaseCurr': _inr(0),
      'availableAmountInBaseCurr': _inr(36000),
      'equivalentLimitContribution': _inr(0),
    },
  ],
};

final _groups = {
  'collateralgroupdtos': [
    {
      'poolId': 'POOL9',
      'externalReferenceId': 'EXT-ALPHA',
      'groupAmount': _money(1000),
      'groupUtilizedAmount': _money(200),
      'groupBlockAmount': _money(50),
      'availableAmount': _money(600),
    },
  ],
};

Map<String, dynamic> _collateralDto(dynamic details) => {
      'collateralDTO': {
        'collateralType': 'INVENTORY',
        'collateralValue': _money(800),
        'limitContribution': _money(700),
        'utilizationAmount': _money(120),
        'blockAmount': {'currency': 'USD'},
        'availableAmount': _money(580),
        'covenantDTO': [
          {'covenantName': 'COV-C', 'revisionDate': '2026-06-01T00:00:00'},
        ],
        'collateralDetails': details,
      },
    };

final _inventory = [
  {
    'costOfFinishedGoods': {'amount': 1500},
    'lienAmount': _money(20),
    'products': [
      {'productCode': 'PRD1', 'productDescription': 'Steel coils', 'stockQuantity': 40, 'pricePerUnit': _money(5)},
    ],
  },
];

ResponseHandler<Map<String, dynamic>> _ok(Map<String, dynamic> body) =>
    ResponseHandler.success({'statusCode': 200, 'headers': <String, dynamic>{}, 'rawBody': jsonEncode(body), 'body': body});

class _FakeApi implements ObdxCorpCreditFacilityApi {
  final calls = <String>[];

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchLiabilities({String? partyId}) async {
    calls.add('liabilities partyId=${partyId ?? '<none>'}');
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
  Future<ResponseHandler<Map<String, dynamic>>> fetchCollateralGroups(String liabilityId,
      {required String partyId, String? branchCode, String currencyCode = 'INR'}) async {
    calls.add('groups $liabilityId partyId=$partyId currency=$currencyCode');
    return _ok(_groups);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchCollateral(String liabilityId, String collateralId) async {
    calls.add('collateral $liabilityId $collateralId');
    return _ok(_collateralDto(_inventory));
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

class _FakeDashboards implements DashboardRepository {
  _FakeDashboards([this.names]);

  /// The server layout's component names; null = the call fails.
  final List<String>? names;
  final asked = <String>[];

  @override
  Future<ResponseHandler<DashboardConfig>> fetchConfig({
    required String dashboardClass,
    required String dashboardClassValue,
  }) async {
    asked.add('$dashboardClass/$dashboardClassValue');
    final n = names;
    if (n == null) return ResponseHandler.exceptionError();
    return ResponseHandler.success(
      DashboardConfig(
        dashboardId: '1',
        dashboardName: 'credit-facility',
        dashboardDescription: '',
        layoutsByBreakpoint: {
          for (final b in DashboardBreakpoint.values)
            b: [for (final c in n) DashboardLayoutItem(componentName: c, module: 'credit-facility')],
        },
      ),
      code: 200,
    );
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

    CfCollateralSummary summary() {
      final listed = CfCollateral.listFromPayload(_collaterals);
      final group = CfCollateralGroup.listFromPayload(_groups).single;
      return CfCollateralSummary(
        groups: [group.withLinked(CfCollateralGroup.fromPayload(_group, listed)!.linked)],
        collaterals: listed,
      );
    }

    test('collateral summary: ungrouped first, then groups; utilized %; types; search', () {
      final s = summary();
      final rows = s.entries;
      expect(rows.length, 2, reason: 'COL1 is in POOL9, so only COL2 is loose');
      expect((rows.first as CfLooseEntry).collateral.code, 'COL2');
      final g = (rows.last as CfGroupEntry).group;
      expect(g.externalReferenceId, 'EXT-ALPHA');
      expect(g.utilizedPercent, 25, reason: '(200 + 50) x 100 / 1000');
      expect(g.linked.single.type, 'PROPERTY', reason: 'from the listed category');
      expect(s.types, ['PROPERTY', 'VEHICLE']);
      expect(rows.where((r) => r.matches('truck')).single, isA<CfLooseEntry>());
      expect(rows.where((r) => r.matches('pool9')).single, isA<CfGroupEntry>());
    });

    test('collateral filter: OBDX modes, with the defects fixed', () {
      final rows = summary().entries;
      List<String> ids(CfCollateralFilter f) => [
            for (final r in f.apply(rows))
              switch (r) {
                CfGroupEntry(:final group) => group.poolId,
                CfLooseEntry(:final collateral) => collateral.code,
              },
          ];
      const byGroup = CfCollateralFilterMode.byGroup;
      const byNon = CfCollateralFilterMode.byNonGroup;
      const byColl = CfCollateralFilterMode.byCollateral;
      expect(ids(CfCollateralFilter.none), ['COL2', 'POOL9']);
      expect(ids(const CfCollateralFilter(mode: byGroup)), ['POOL9']);
      expect(ids(const CfCollateralFilter(mode: byGroup, groupId: 'alpha')), ['POOL9'], reason: 'externalReferenceId');
      expect(ids(const CfCollateralFilter(mode: byGroup, groupId: 'POOL9')), isEmpty, reason: 'not poolId');
      expect(ids(const CfCollateralFilter(mode: byGroup, availableMin: 700)), isEmpty, reason: 'group available 600');
      expect(ids(const CfCollateralFilter(mode: byNon)), ['COL2']);
      expect(ids(const CfCollateralFilter(mode: byNon, collateralId: 'col9')), isEmpty, reason: 'ID applied (ignored in OBDX)');
      expect(ids(const CfCollateralFilter(mode: byNon, amountMax: 400)), isEmpty, reason: 'collateral value 500');
      expect(ids(const CfCollateralFilter(mode: byColl, type: 'PROPERTY')), ['POOL9'], reason: 'via its linked collateral');
      expect(ids(const CfCollateralFilter(mode: byColl, collateralId: 'col1')), ['POOL9']);
      expect(ids(const CfCollateralFilter(mode: byColl, amountMin: 900)), ['POOL9'], reason: 'one-sided range, group 1000');
    });

    test('overview: synopsis sums in local currency, the meter split, zero totals', () {
      final f = CfSynopsis.facilities(CfFacility.listFromPayload(_payload))!;
      expect([f.total, f.utilized, f.available], [480000, 120000, 360000], reason: 'main lines only, x80 INR');
      expect([f.utilizedPercent, f.availablePercent], [25, 75]);
      expect(f.currency, 'INR');
      final c = CfSynopsis.collaterals(CfCollateral.listFromPayload(_collaterals))!;
      expect([c.total, c.utilized, c.available], [56000, 12000, 44000], reason: 'utilized + block');
      expect(c.utilizedPercent, 21);
      expect(CfSynopsis.facilities(const []), isNull);
      expect(const CfSynopsis(total: 0, utilized: 0, available: 0).utilizedPercent, 0);
    });

    test('overview: allocation by category with shares; collateral % without dividing by zero', () {
      final a = CfAllocation.facilities(CfFacility.listFromPayload(_payload))!;
      expect([for (final s in a.slices) s.category], ['AR FINANCE', 'TERM LOAN']);
      expect([for (final s in a.slices) s.share], [83.33, 16.67]);
      expect(a.slices.first.rows.length, 5);
      expect(a.total, 480000);
      final listed = CfCollateral.listFromPayload(_collaterals);
      final c = CfAllocation.collaterals(listed)!;
      expect([for (final s in c.slices) s.share], [100, 0]);
      expect(listed.first.allocationUtilizedPercent, 21.43);
      expect(listed.last.allocationUtilizedPercent, 0, reason: 'zero contribution');
    });

    test('overview: server layout names, unknown skipped, all four when none known', () {
      expect(CfOverviewWidget.fromLayout(['facility-synopsis', 'x', 'facility-synopsis', 'collateral-allocation']),
          [CfOverviewWidget.facilitySynopsis, CfOverviewWidget.collateralAllocation]);
      expect(CfOverviewWidget.fromLayout(['other']), CfOverviewWidget.values);
    });

    test('collateral details: list or single object, block 0, columns and currency', () {
      final d = CfCollateralDetail.fromPayload(_collateralDto(_inventory), 'COL1')!;
      expect(d.type, 'INVENTORY');
      expect(d.block!.amount, 0);
      expect(d.covenants.single.name, 'COV-C');
      expect(d.rows.single['lienAmount'], isNotNull);
      expect(d.columns!.last.field, 'products');
      expect(d.currency, 'USD');
      final single = CfCollateralDetail.fromPayload(_collateralDto({'vehicleType': 'Truck'}), 'C')!;
      expect(single.rows.single['vehicleType'], 'Truck');
      expect(CfCollateralDetail.fromPayload(_collateralDto(const [])..['collateralDTO']['collateralType'] = 'GOLD', 'C')!.columns,
          isNull);
      expect(cfCollateralColumns.length, 16);
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

  test('repository: collateral summary sends the user party, then one call per group', () async {
    final api = _FakeApi();
    final r = await CorpCreditFacilityRepository(api: api).fetchCollateralSummary('P1');
    final s = (r as Success<CfCollateralSummary>).data!;
    expect(s.groups.single.linked.single.code, 'COL1');
    expect(api.calls, [
      'liabilities partyId=<none>',
      'collaterals L1 partyId=P1 currency=INR',
      'groups L1 partyId=P1 currency=INR',
      'group L1 POOL9',
    ]);
    final d = await CorpCreditFacilityRepository(api: api).fetchCollateral('COL1');
    expect((d as Success<CfCollateralDetail>).data!.code, 'COL1');
    expect(api.calls.last, 'collateral L1 COL1');
  });

  test('repository: overview widgets send partyId=null as text, then the user party', () async {
    final api = _FakeApi();
    final repo = CorpCreditFacilityRepository(api: api);
    expect((await repo.fetchOverviewFacilities('P1') as Success<List<CfFacility>>).data!.length, 6);
    await repo.fetchOverviewCollaterals('P1');
    expect(api.calls, [
      'liabilities partyId=null',
      'facilities L1 partyId=P1 branch=B01 currency=INR',
      'liabilities partyId=null',
      'collaterals L1 partyId=P1 currency=INR',
    ]);
  });

  test('overview layout: MODULE/credit-facility from the server; all four when it fails', () async {
    final server = _FakeDashboards(['facility-synopsis', 'facility-allocation']);
    final c1 = ProviderContainer(overrides: [dashboardRepositoryProvider.overrideWithValue(server)]);
    addTearDown(c1.dispose);
    expect(await c1.read(cfOverviewLayoutProvider(DashboardBreakpoint.large).future),
        [CfOverviewWidget.facilitySynopsis, CfOverviewWidget.facilityAllocation]);
    expect(server.asked, ['MODULE/credit-facility']);
    final c2 = ProviderContainer(overrides: [dashboardRepositoryProvider.overrideWithValue(_FakeDashboards())]);
    addTearDown(c2.dispose);
    expect(await c2.read(cfOverviewLayoutProvider(DashboardBreakpoint.large).future), CfOverviewWidget.values);
  });

  group('menu', () {
    test('Credit Facility Management ▸ Credit Facility ▸ pages; hidden without rights', () {
      const lc = LcPermissions(viewImport: true, viewExport: true, initiate: true, amend: true);
      final item = CorpNavDestination.navItems(lc).firstWhere((i) => i.id == 'creditFacility');
      expect(item.label, 'Credit Facility Management');
      expect([for (final g in item.children) g.label], ['Overview', 'Credit Facility', 'Collaterals']);
      expect(item.children.first.children, isEmpty);
      expect(item.children.first.id, 'creditFacility.overview');
      expect([for (final c in item.children[1].children) c.label], ['Facility Summary', 'Facility Details']);
      expect([for (final c in item.children.last.children) c.label], ['Collateral Summary', 'Collateral Details']);
      for (final page in CfPage.values) {
        expect(CorpNavDestination.cfPageFromNavId(CorpNavDestination.navIdForCfPage(page)), page);
      }
      expect(CorpNavDestination.navIdForCfPage(CfPage.collateralSummary), 'creditFacility.collaterals.collateralSummary');
      final onlyCollaterals = CorpNavDestination.navItems(lc,
          cfPermissions: const CfPermissions(facilitySummary: false, facilityDetails: false));
      expect([for (final g in onlyCollaterals.firstWhere((i) => i.id == 'creditFacility').children) g.label],
          ['Overview', 'Collaterals']);
      final none = CorpNavDestination.navItems(lc,
          cfPermissions: const CfPermissions(
              overview: false,
              facilitySummary: false,
              facilityDetails: false,
              collateralGroups: false,
              collateralDetails: false));
      expect(none.any((i) => i.id == 'creditFacility'), isFalse);
    });
  });

  group('screens', () {
    Future<_FakeApi> pump(WidgetTester tester, Widget child,
        {double width = 390, List<String>? layout, bool scroll = true}) async {
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
            dashboardRepositoryProvider.overrideWithValue(_FakeDashboards(layout)),
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
            home: Scaffold(
              body: scroll ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: child) : child,
            ),
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

    testWidgets('details: a linked collateral code opens Collateral Details', (tester) async {
      String? opened;
      await pump(tester, FacilityDetailsPage(initialKey: 'MAIN1_1', onExit: () {}, onOpenCollateral: (c) => opened = c));
      await tester.tap(find.text('Linked Collateral'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('COL1'));
      expect(opened, 'COL1');
    });

    testWidgets('collateral summary (phone): loose card, group, linked, filter', (tester) async {
      String? opened;
      await pump(tester, CollateralSummaryPage(onOpen: (c) => opened = c));
      expect(find.text('Not a part of any group'), findsOneWidget);
      expect(find.text('Truck fleet'), findsOneWidget);
      expect(find.text('12.5%'), findsOneWidget);
      expect(find.text('POOL9'), findsOneWidget);
      expect(find.text('25% Utilized'), findsOneWidget);
      await tester.tap(find.text('Linked Collateral'));
      await tester.pumpAndSettle();
      expect(find.text('Warehouse'), findsOneWidget);
      await tester.tap(find.text('COL1'));
      expect(opened, 'COL1');

      await tester.tap(find.byTooltip('Collateral Summary Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By Collateral Group'));
      await tester.pumpAndSettle();
      expect(find.text('Group ID'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Not a part of any group'), findsNothing);
      expect(find.text('POOL9'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'nothing-like-this');
      await tester.pumpAndSettle();
      expect(find.text('No collaterals to show.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('collateral details (web): Choose Collateral, amounts, table, products, covenants', (tester) async {
      await pump(tester, CollateralDetailsPage(onExit: () {}), width: 1280);
      expect(find.text('Choose Collateral'), findsWidgets);
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      expect(find.text('Collateral Amount (After Haircut)'), findsOneWidget);
      expect(find.text('COV-C'), findsOneWidget);
      await tester.tap(find.text('More Information'));
      await tester.pumpAndSettle();
      expect(find.text('Show Less Information'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Cost Of Obsolete Inventory'), findsOneWidget);
      expect(find.text('--'), findsWidgets, reason: 'missing columns');
      await tester.ensureVisible(find.text('Inventory Product Details').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventory Product Details').last);
      await tester.pumpAndSettle();
      expect(find.text('Product Details'), findsOneWidget);
      expect(find.text('Steel coils'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overview (web): server layout, paired synopses, allocation table, toggle, tabs, links', (tester) async {
      var summary = 0;
      String? facility;
      await pump(
        tester,
        CfOverviewPage(onFacilitySummary: () => summary++, onFacility: (k) => facility = k),
        width: 1280,
        layout: ['facility-synopsis', 'collateral-synopsis', 'facility-allocation'],
      );
      expect(find.text('Credit Facility'), findsOneWidget);
      expect(find.text('Collateral'), findsOneWidget);
      expect(find.text('Collateral Category Allocation'), findsNothing, reason: 'not in the layout');
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget, reason: 'no Collateral Summary callback');
      await tester.tap(find.text('View Details'));
      expect(summary, 1);

      expect(find.text('*Equivalent Local Currency'), findsOneWidget);
      expect(find.text('83.33%'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('MAIN6'), findsNothing, reason: 'TERM LOAN tab not selected');
      expect(find.text('25 % Utilized'), findsWidgets);
      final usd = find.textContaining('USD');
      expect(usd, findsWidgets);
      await tester.tap(find.text('Local Currency'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(DataTable), matching: find.textContaining('USD')), findsNothing);
      await tester.tap(find.text('16.67%'));
      await tester.pumpAndSettle();
      expect(find.text('MAIN6'), findsOneWidget);
      await tester.tap(find.text('MAIN6'));
      expect(facility, 'MAIN6_1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('overview (phone): all four when the layout fails; cards, no table', (tester) async {
      await pump(tester, const CfOverviewPage());
      expect(find.text('Collateral Category Allocation'), findsOneWidget);
      expect(find.text('Facility Allocation'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('View Details'), findsNothing, reason: 'no callbacks, no links');
      expect(find.text('21.43 % Utilized'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('workspace: Overview > View Details > Back returns to the Overview', (tester) async {
      var home = 0;
      await pump(
        tester,
        CorpCreditFacilityWorkspace(page: CfPage.overview, onBack: () => home++),
        width: 1280,
        layout: ['facility-synopsis'],
        scroll: false,
      );
      expect(find.text('Overview'), findsOneWidget);
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();
      expect(find.text('Facility Summary'), findsOneWidget);
      expect(find.text('(Showing 5 out of 7 items)'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsOneWidget);
      expect(home, 0);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      expect(home, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('collateral details (phone): rows instead of a table', (tester) async {
      await pump(tester, CollateralDetailsPage(initialCode: 'COL1', onExit: () {}));
      await tester.tap(find.text('More Information'));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('Cost Of Finished Goods'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
