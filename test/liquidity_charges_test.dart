import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_bank/l10n/app_localizations.dart';
import 'package:demo_bank/src/core/config/locale_config.dart';
import 'package:demo_bank/src/core/models/corp/liquidity_charges_models.dart';
import 'package:demo_bank/src/core/theme/app_theme.dart';
import 'package:demo_bank/src/infra/network/apis/corp/obdx_corp_liquidity_api.dart';
import 'package:demo_bank/src/infra/network/response_handler.dart';
import 'package:demo_bank/src/infra/repositories/corp/corp_liquidity_repository.dart';
import 'package:demo_bank/src/view/providers/corp/corp_liquidity_providers.dart';
import 'package:demo_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:demo_bank/src/view/screens/corp/liquidity/charges_inquiry_page.dart';
import 'package:demo_bank/src/view/screens/corp/liquidity/lm_menu.dart';
import 'package:demo_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/widgets/corp_nav_content.dart';

// Shapes follow OBDX lm-charges-inquiry (docs/obdx/features/
// liquidity-management.md §10). No samples exist; values are made up.

ResponseHandler<Map<String, dynamic>> _ok(Map<String, dynamic> body) =>
    ResponseHandler.success({'statusCode': 200, 'headers': <String, dynamic>{}, 'rawBody': jsonEncode(body), 'body': body});

final _charges = {
  'items': [
    {
      'fromDate': '2026-10-01T00:00:00',
      'toDate': '2026-10-15T00:00:00',
      'description': 'Sweep charge',
      'currency': 'USD',
      'amount': 25.5,
      'account': {'value': 'X', 'displayValue': 'xxxx1234'},
      'accountName': 'Acme Ops',
      'accountCurrency': 'INR',
      'exchangeRate': 83.1,
      'additionalInfo': 'Monthly sweep fee',
      'collectionDetails': {'amount': 2119.05, 'date': '2026-10-16T00:00:00', 'status': 'F', 'errorDescription': 'Insufficient funds'},
    },
    {
      'fromDate': '2026-09-01T00:00:00',
      'toDate': '2026-09-30T00:00:00',
      'description': 'Pool charge',
      'currency': 'INR',
      'amount': {'amount': 100, 'currency': 'INR'},
      'accountCurrency': 'INR',
      'exchangeRate': 1,
      'collectionDetails': {'amount': 100, 'date': '2026-10-01T00:00:00', 'status': 'S'},
    },
  ],
};

class _FakeApi implements ObdxCorpLiquidityApi {
  _FakeApi({this.failStatuses = false});

  final bool failStatuses;
  final calls = <String>[];

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchChargeDefinitions() async {
    calls.add('definitions');
    return _ok({
      'items': [
        {'code': 'SWP', 'description': 'Sweep charge'},
        {'code': 'POOL', 'description': 'Pool charge'},
      ],
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchCollectionStatuses() async {
    calls.add('statuses');
    if (failStatuses) return ResponseHandler.error(500, 'down');
    return _ok({
      'enumRepresentations': [
        {
          'data': [
            {'code': 'S', 'description': 'Success'},
            {'code': 'F', 'description': 'Failed'},
          ],
        },
      ],
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchMaintenances() async {
    calls.add('maintenances');
    return _ok({
      'configurationDetails': [
        {'propertyId': 'LM_CHARGE_INQUIRY_MAX_PERIOD', 'propertyValue': '60'},
      ],
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchCharges(String? q) async {
    calls.add('charges q=$q');
    return _ok(_charges);
  }

  @override
  Future<ResponseHandler<List<int>>> downloadCharges(String? q) async {
    calls.add('download q=$q');
    return ResponseHandler.success(utf8.encode('a,b'), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('model', () {
    test('q: one EQUALS criterion per filled field, dates yyyy-MM-dd; none when empty', () {
      final q = LmChargeQuery(code: 'SWP', status: 'F', from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31)).toQ();
      expect(jsonDecode(q!), {
        'criteria': [
          {'operand': 'code', 'operator': 'EQUALS', 'value': ['SWP']},
          {'operand': 'collectionStatus', 'operator': 'EQUALS', 'value': ['F']},
          {'operand': 'fromDate', 'operator': 'EQUALS', 'value': ['2026-10-01']},
          {'operand': 'toDate', 'operator': 'EQUALS', 'value': ['2026-10-31']},
        ],
      });
      expect(jsonDecode(LmChargeQuery(from: DateTime(2026, 10, 1)).toQ()!)['criteria'], hasLength(1));
      expect(const LmChargeQuery().toQ(), isNull);
    });

    test('range: 30 days allowed, 31 not', () {
      expect(LmChargeQuery(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31)).tooLong, isFalse);
      expect(LmChargeQuery(from: DateTime(2026, 9, 30), to: DateTime(2026, 10, 31)).tooLong, isTrue);
    });

    test('rows: number or object amounts in their currencies; status text from the enum', () {
      final rows = LmCharge.listFromPayload(_charges);
      expect(rows.first.amount!.amount, 25.5);
      expect(rows.first.amount!.currency, 'USD');
      expect(rows.first.collectionAmount!.currency, 'INR', reason: 'accountCurrency');
      expect(rows.first.account, 'xxxx1234');
      expect(rows.first.errorDescription, 'Insufficient funds');
      expect(rows.last.amount!.amount, 100);
      const setup = LmChargeSetup(statuses: [LmOption(code: 'F', description: 'Failed')]);
      expect(setup.statusText('F'), 'Failed');
      expect(setup.statusText('X'), 'X', reason: 'raw code when not in the enum');
      expect(LmChargeSetup.maxDaysFrom({
        'configurationDetails': [
          {'propertyId': 'LM_CHARGE_INQUIRY_MAX_PERIOD', 'propertyValue': '45'},
        ],
      }), 45);
    });
  });

  group('repository', () {
    test('setup is best effort; the maintained period is read, not applied', () async {
      final api = _FakeApi(failStatuses: true);
      final setup = await CorpLiquidityRepository(api: api).fetchChargeSetup();
      expect([for (final d in setup.definitions) d.code], ['SWP', 'POOL']);
      expect(setup.statuses, isEmpty);
      expect(setup.maintainedMaxDays, 60);
      expect(lmChargeMaxDays, 30);
      expect(api.calls, unorderedEquals(['definitions', 'statuses', 'maintenances']));
    });

    test('search and download send the same q', () async {
      final api = _FakeApi();
      final repo = CorpLiquidityRepository(api: api);
      final query = LmChargeQuery(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 2));
      expect((await repo.fetchCharges(query) as Success<List<LmCharge>>).data!.length, 2);
      await repo.downloadCharges(query);
      expect(api.calls.last.replaceFirst('download', 'charges'), api.calls[api.calls.length - 2]);
    });
  });

  group('menu', () {
    const lc = LcPermissions(viewImport: true, viewExport: true, initiate: true, amend: true);

    test('Liquidity Management sits after Trade Finance, before Credit Facility Management', () {
      final ids = [for (final i in CorpNavDestination.navItems(lc)) i.id];
      expect(ids.indexOf('liquidityManagement'), ids.indexOf('tradeFinance') + 1);
      expect(ids.indexOf('creditFacility'), ids.indexOf('liquidityManagement') + 1);
      final item = CorpNavDestination.navItems(lc).firstWhere((i) => i.id == 'liquidityManagement');
      expect([for (final c in item.children) c.label], ['Overview', 'Charges Inquiry']);
      expect(CorpNavDestination.lmPageFromNavId(item.children.last.id), LmPage.chargesInquiry);
      expect(CorpNavDestination.fromNavId(item.children.last.id), CorpNavDestination.liquidityManagement);
    });

    test('hidden when neither page is allowed', () {
      final items =
          CorpNavDestination.navItems(lc, lmPermissions: const LmPermissions(overview: false, chargesInquiry: false));
      expect(items.any((i) => i.id == 'liquidityManagement'), isFalse);
    });
  });

  group('screen', () {
    Future<_FakeApi> pump(WidgetTester tester, {double width = 390, VoidCallback? onCancel}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _FakeApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [corpLiquidityRepositoryProvider.overrideWithValue(CorpLiquidityRepository(api: api))],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ChargesInquiryPage(onCancel: onCancel ?? () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    /// Opens [field]'s date picker and picks [day], a month back when
    /// [previousMonth].
    Future<void> pick(WidgetTester tester, String field, int day, {bool previousMonth = false}) async {
      await tester.tap(find.widgetWithText(LcDateField, field));
      await tester.pumpAndSettle();
      if (previousMonth) {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('$day')).first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets('dates are required; over 30 days stops before any request', (tester) async {
      final api = await pump(tester);
      expect(find.text('Difference between From Date and To Date should not be greater than 30 days.'), findsOneWidget);
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('From Date is required.'), findsOneWidget);
      expect(find.text('To Date is required.'), findsOneWidget);

      await pick(tester, 'From Date', 1, previousMonth: true);
      await pick(tester, 'To Date', 28);
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('The date range to search charges cannot be more than 30 days.'), findsOneWidget);
      expect(api.calls.where((c) => c.startsWith('charges')), isEmpty);
    });

    testWidgets('phone: search lists cards; details popup; Reset; Cancel below the list', (tester) async {
      var cancelled = 0;
      final api = await pump(tester, onCancel: () => cancelled++);
      await tester.tap(find.widgetWithText(LcPickerField<String>, 'Collection Status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Failed').last);
      await tester.pumpAndSettle();
      await pick(tester, 'From Date', 1);
      await pick(tester, 'To Date', 28);
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      final q = jsonDecode(api.calls.last.substring('charges q='.length)) as Map;
      expect([for (final c in q['criteria'] as List) c['operand']], ['collectionStatus', 'fromDate', 'toDate']);

      expect(find.text('Charges List'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('Sweep charge'), findsWidgets);
      expect(find.text('xxxx1234 / Acme Ops'), findsOneWidget);
      expect(find.text('83.1'), findsOneWidget);
      expect(find.text('Failed'), findsWidgets);

      await tester.tap(find.byTooltip('Click for more details').first);
      await tester.pumpAndSettle();
      expect(find.text('Monthly sweep fee'), findsOneWidget);
      expect(find.text('Insufficient funds'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget, reason: 'moved below the list');
      await tester.tap(find.text('Cancel'));
      expect(cancelled, 1);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('From Date is required.'), findsOneWidget, reason: 'Reset cleared the dates');
      expect(tester.takeException(), isNull);
    });

    testWidgets('web: two-column form, the table, sorting by date', (tester) async {
      await pump(tester, width: 1280);
      await pick(tester, 'From Date', 1);
      await pick(tester, 'To Date', 20);
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Collection Status'), findsWidgets);
      final first = find.descendant(of: find.byType(DataTable), matching: find.text('Sweep charge'));
      final second = find.descendant(of: find.byType(DataTable), matching: find.text('Pool charge'));
      expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
      await tester.tap(find.text('From Date').last);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(second).dy, lessThan(tester.getTopLeft(first).dy), reason: 'September first');
      expect(tester.takeException(), isNull);
    });
  });
}
