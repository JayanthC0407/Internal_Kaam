import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_bill.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_trade_finance_repository.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/export_bill_detail_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/export_bill_list_page.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_menu.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';

// A `billDTOs[]` row with the fields the OBDX web list reads, and a `bill`
// detail with the bill model's fields. Values are made up.
Map<String, dynamic> _billJson(
  String id, {
  String status = 'ACTIVE',
  String? lcRefNo = 'EXP001',
  String operation = 'NEGOTIATION',
  String stage = 'FIN',
}) =>
    {
      'id': id,
      'productName': 'Export Bill Under LC',
      'operationName': operation,
      'stageName': stage,
      'transactionDate': '2026-09-20T00:00:00',
      'amount': {'currency': 'GBP', 'amount': 45000},
      'equivalentAmount': {'currency': 'GBP', 'amount': 45000},
      'outstandingAmount': {'currency': 'GBP', 'amount': 30000},
      'contractStatus': status,
      'counterPartyName': 'Northwind Imports',
      'counterPartyAddress': {'line1': '9 Harbour St', 'country': 'AE'},
      'name': 'Contoso Exports',
      'partyId': {'value': 'P1', 'displayValue': '***001'},
      'branchId': '001',
      'lcRefNo': lcRefNo,
      'maturityDate': '2026-12-19T00:00:00',
      'tenor': '90',
      'docAttached': 'Y',
      'bankName': 'Bank of the Gulf',
      'swiftId': 'BANKAEADXXX',
      'shipmentDetails': {'source': 'London', 'destination': 'Dubai'},
      'goods': [
        {
          'code': 'TEXT',
          'description': 'Cotton fabric',
          'noOfUnits': 100,
          'pricePerUnit': 450
        },
      ],
      'commissions': [
        {
          'commitment': 'Negotiation commission',
          'amount': {'currency': 'GBP', 'amount': 120}
        },
      ],
      'discrepancies': [
        {
          'description': 'Late presentation',
          'receivedDate': '2026-09-22',
          'status': 'RESOLVED'
        },
      ],
      'swiftMessages': [
        {
          'messageId': 'SW-1',
          'date': '2026-09-21',
          'description': 'Advice of discrepancy',
          'messageType': 'MT 734',
          'message': ':20:REF'
        },
      ],
      'advices': [
        {'id': 'ADV-1', 'date': '2026-09-23', 'description': 'Payment advice'},
      ],
    };

CorpExportBill _bill(String id,
        {String status = 'ACTIVE', String? lcRefNo = 'EXP001'}) =>
    CorpExportBill.fromJson(_billJson(id, status: status, lcRefNo: lcRefNo))!;

class _FakeRepository implements CorpTradeFinanceRepository {
  _FakeRepository({this.bills = const [], this.detail});

  final List<CorpExportBill> bills;
  final CorpExportBill? detail;
  final List<Map<String, dynamic>> queries = [];

  @override
  Future<ResponseHandler<List<CorpExportBill>>> searchExportBills(
    Map<String, dynamic> query,
  ) async {
    queries.add(query);
    return ResponseHandler.success(bills, code: 200);
  }

  @override
  Future<ResponseHandler<CorpExportBill>> fetchExportBill(String id) async =>
      ResponseHandler.success(detail!, code: 200);

  @override
  Future<ResponseHandler<LcLookups>> fetchLookups() async =>
      ResponseHandler.success(LcLookups.empty, code: 200);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _allowed = LcPermissions(
  viewImport: true,
  viewExport: true,
  initiate: true,
  amend: true,
);

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required _FakeRepository repository,
  double width = 1100,
  List<String>? pushed,
}) async {
  tester.view.physicalSize = Size(width, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        corpTradeFinanceRepositoryProvider.overrideWithValue(repository),
        lcPermissionsProvider.overrideWithValue(_allowed),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (settings) {
          pushed?.add(settings.name!);
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _listHome() => const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: ExportBillListPage(),
      ),
    );

Future<void> _openTab(WidgetTester tester, String tab) async {
  await tester.ensureVisible(find.text(tab).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(tab).first);
  await tester.pumpAndSettle();
}

void main() {
  group('the search, as the OBDX web client builds it', () {
    test('every criterion, operand and operator', () {
      final search = ExportBillSearch(
        billNumber: 'eb001',
        importerName: 'north',
        status: ExportBillStatus.hold,
        currency: 'GBP',
        fromAmount: 1000,
        toAmount: 50000,
        dateFrom: DateTime(2026, 9, 1),
        dateTo: DateTime(2026, 9, 30),
      );
      expect(search.criteria, [
        {
          'operand': 'billType',
          'operator': 'EQUALS',
          'value': ['EXPORT']
        },
        {
          'operand': 'transactionType',
          'operator': 'EQUALS',
          'value': ['CONVENTIONAL']
        },
        {
          'operand': 'status',
          'operator': 'ENUM',
          'value': ['HOLD']
        },
        {
          'operand': 'billReferenceNo',
          'operator': 'EQUALS',
          'value': ['EB001']
        },
        {
          'operand': 'ccy',
          'operator': 'EQUALS',
          'value': ['GBP']
        },
        {
          'operand': 'drawee',
          'operator': 'CONTAINS',
          'value': ['north']
        },
        {
          'operand': 'billAmtFrom',
          'operator': 'GREATERTHANEQUALTO',
          'value': [1000]
        },
        {
          'operand': 'billAmtTo',
          'operator': 'LESSTHANEQUALTO',
          'value': [50000]
        },
        {
          'operand': 'billDateFrom',
          'operator': 'GREATERTHANEQUALTO',
          'value': ['2026-09-01']
        },
        {
          'operand': 'billDateTo',
          'operator': 'LESSTHANEQUALTO',
          'value': ['2026-09-30']
        },
      ]);
    });

    test('opens on Active bills, as the web screen does', () {
      final q = ExportBillSearch.initial.toQuery(partyId: 'P1');
      expect(q['partyIds'], 'P1');
      final criteria =
          (jsonDecode(q['q'] as String) as Map)['criteria'] as List;
      expect(criteria, hasLength(3));
      expect(criteria.last, {
        'operand': 'status',
        'operator': 'ENUM',
        'value': ['ACTIVE']
      });
    });

    test('each filter comes off on its own', () {
      final s = ExportBillSearch.initial.without(ExportBillFilter.status);
      expect(s.status, isNull);
      expect(s.activeFilters, isEmpty);
    });
  });

  group('reading a bill', () {
    test('the list row fields the web table reads', () {
      final b = _bill('EB001');
      expect(b.id, 'EB001');
      expect(b.productName, 'Export Bill Under LC');
      expect(b.amount?.amount, 45000);
      expect(b.status, 'ACTIVE');
      expect(b.importerName, 'Northwind Imports');
      expect(b.exporterName, 'Contoso Exports');
      expect(b.lcRefNo, 'EXP001');
    });

    test('financed: negotiated / discounted / purchased at the FIN stage', () {
      expect(_bill('A').isFinanced, isTrue);
      expect(
        CorpExportBill.fromJson(_billJson('B', stage: 'BOOK'))!.isFinanced,
        isFalse,
      );
      expect(
        CorpExportBill.fromJson(_billJson('C', operation: 'COLLECTION'))!
            .isFinanced,
        isFalse,
      );
    });

    test('the detail lists', () {
      final b = _bill('EB001');
      expect(b.documentsAttached, isTrue);
      expect(b.charges.single.label, 'Negotiation commission');
      expect(b.discrepancies.single.description, 'Late presentation');
      expect(b.swiftMessages.single.messageType, 'MT 734');
      expect(b.advices.single.id, 'ADV-1');
    });

    test('the response wrappers: billDTOs and bill', () {
      expect(
        CorpExportBill.listFromPayload({
          'billDTOs': [_billJson('X1'), _billJson('X2')],
        }).map((b) => b.id),
        ['X1', 'X2'],
      );
      expect(
        CorpExportBill.fromDetailPayload({'bill': _billJson('X3')})?.id,
        'X3',
      );
    });
  });

  test('View Bills sits under Export LC, with View Export LC', () {
    expect(LcMenuAction.exportViewBills.group, LcMenuGroup.exportLc);
    const noView = LcPermissions(
      viewImport: true,
      viewExport: false,
      initiate: true,
      amend: true,
    );
    expect(LcMenuAction.exportViewBills.isAllowed(noView), isFalse);
    expect(LcMenuAction.exportViewBills.isAllowed(_allowed), isTrue);
  });

  group('the bills page', () {
    final bills = [_bill('EB001'), _bill('EB002', status: 'HOLD')];

    testWidgets('a table on a wide screen, cards on a phone', (tester) async {
      await _pump(tester, _listHome(),
          repository: _FakeRepository(bills: bills));
      expect(find.text('2 export bills'), findsOneWidget);
      expect(find.text('Release against'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        _listHome(),
        repository: _FakeRepository(bills: bills),
        width: 380,
      );
      expect(find.text('Importer: Northwind Imports'), findsNWidgets(2));
      expect(find.text('Release against'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('starts on Active, and a chip takes it off', (tester) async {
      final repository = _FakeRepository(bills: bills);
      await _pump(tester, _listHome(), repository: repository, width: 380);
      expect(find.text('Status: Active'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove filter'));
      await tester.pumpAndSettle();
      final q = repository.queries.last['q'] as String;
      expect(q.contains('"status"'), isFalse);
    });

    testWidgets('the form sends the chosen status', (tester) async {
      final repository = _FakeRepository(bills: bills);
      await _pump(tester, _listHome(), repository: repository, width: 380);
      await tester.tap(find.byTooltip('Search & filter'));
      await tester.pumpAndSettle();
      expect(find.text('Search export bills'), findsOneWidget);
      await tester.tap(find.text('Hold'));
      await tester.pump();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(repository.queries.last['q'], contains('"HOLD"'));
    });

    testWidgets('opening a bill goes to its detail', (tester) async {
      final pushed = <String>[];
      await _pump(
        tester,
        _listHome(),
        repository: _FakeRepository(bills: bills),
        width: 380,
        pushed: pushed,
      );
      await tester.tap(find.text('EB001'));
      await tester.pumpAndSettle();
      expect(pushed, contains(CorpRoutesConst.exportBillDetailScreen));
    });
  });

  group('the bill detail', () {
    Widget detail() => const ExportBillDetailScreen(
          args: ExportBillArgs(billId: 'EB001'),
        );

    testWidgets('the manual\'s five tabs, General first', (tester) async {
      await _pump(
        tester,
        detail(),
        repository: _FakeRepository(detail: _bill('EB001')),
      );
      for (final t in ExportBillDetailScreen.tabs) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.text('Linked to LC EXP001'), findsOneWidget);
      expect(find.text('Yes (documentary)'), findsOneWidget);
      expect(find.text('FINANCED'), findsOneWidget);
    });

    testWidgets('the linked LC opens the export LC', (tester) async {
      final pushed = <String>[];
      await _pump(
        tester,
        detail(),
        repository: _FakeRepository(detail: _bill('EB001')),
        pushed: pushed,
      );
      await tester.tap(find.text('Linked to LC EXP001'));
      await tester.pumpAndSettle();
      expect(pushed, contains(CorpRoutesConst.exportLcDetailScreen));
    });

    testWidgets('a SWIFT message opens in a pop-up', (tester) async {
      await _pump(
        tester,
        detail(),
        repository: _FakeRepository(detail: _bill('EB001')),
      );
      await _openTab(tester, 'SWIFT Messages');
      await tester.tap(find.text('SW-1'));
      await tester.pumpAndSettle();
      expect(find.text('Event date'), findsOneWidget);
      expect(find.text(':20:REF'), findsOneWidget);
    });

    testWidgets('every tab fits a phone', (tester) async {
      const shows = {
        'General': 'Bill details',
        'Discrepancies': 'Late presentation',
        'Charges': 'Charges, commission & taxes',
        'SWIFT Messages': 'SW-1',
        'Advices': 'ADV-1',
      };
      await _pump(
        tester,
        detail(),
        repository: _FakeRepository(detail: _bill('EB001')),
        width: 360,
      );
      for (final t in ExportBillDetailScreen.tabs) {
        await _openTab(tester, t);
        expect(find.text(shows[t]!), findsOneWidget, reason: t);
        expect(tester.takeException(), isNull, reason: t);
      }
    });

    testWidgets('a bill not under an LC has no discrepancies to show',
        (tester) async {
      await _pump(
        tester,
        detail(),
        repository: _FakeRepository(detail: _bill('EB009', lcRefNo: null)),
      );
      await _openTab(tester, 'Discrepancies');
      expect(
        find.text('Discrepancies apply only to bills under an LC.'),
        findsOneWidget,
      );
    });
  });
}
