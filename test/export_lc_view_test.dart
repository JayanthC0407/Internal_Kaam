import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_bill.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_details.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_search.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_trade_finance_repository.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/export_lc_detail_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/export_lc_list_page.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';

// ── Data shaped like the View Export LC / LC detail captures ────────────
// (Values are made up; the field names and shapes are the captured ones.)

Map<String, dynamic> _lcJson(
  String id, {
  String status = 'ACTIVE',
  String expiryStatus = 'NON_EXPIRED',
  String applicant = 'Northwind Imports',
  String applicationDate = '2026-09-01T00:00:00',
  bool transferable = false,
  bool revolving = false,
}) =>
    {
      'id': id,
      'lcType': 'Export',
      'status': status,
      'expiryStatus': expiryStatus,
      'partyName': 'Contoso Exports',
      'partyId': {'value': 'P1', 'displayValue': '***001'},
      'partyAddress': {
        'line1': '1 Dock Road',
        'city': 'London',
        'country': 'GB'
      },
      'counterPartyName': applicant,
      'counterPartyAddress': {'line1': '9 Harbour St', 'country': 'AE'},
      'productName': 'Export LC Sight',
      'applicationDate': applicationDate,
      'expiryDate': '2027-03-31T00:00:00',
      'expiryPlace': 'London',
      'amount': {'currency': 'GBP', 'amount': 200000},
      'outstandingAmount': {'currency': 'GBP', 'amount': 150000},
      'exposure': {'currency': 'GBP', 'amount': 210000},
      'toleranceAbove': 5,
      'toleranceUnder': 5,
      'transferable': transferable,
      'revolving': revolving,
      'revolvingDetails': {
        'frequency': 3,
        'frequencyUnit': 'MONTHS',
        'autoReinstatement': true,
        'cumulativeFrequency': false,
      },
      'irRevocable': true,
      'confirmed': false,
      'transferableType': 'SIGHTPAYMENT',
      'availableWith': 'CITIGB2LXXX',
      'confirmationInstruction': 'WITHOUT',
      'paymentConditionsBene': 'Pay on first presentation',
      'documentPresentationDays': 21,
      'advisingBankCode': 'CITIGB2LXXX',
      'issuingBankCode': 'BANKAEADXXX',
      'requestedConfirmationPartyDetails': {'name': 'Advising Bank Ltd'},
      'shipmentDetails': {
        'source': 'London',
        'destination': 'Dubai',
        'loadingPort': 'Felixstowe',
        'dischargePort': 'Jebel Ali',
        'partial': true,
      },
      'goods': [
        {
          'code': 'TEXT',
          'description': 'Cotton fabric',
          'noOfUnits': 100,
          'pricePerUnit': 20
        },
      ],
      'charges': [],
    };

CorpLetterOfCredit _lc(String id,
        {String status = 'ACTIVE',
        String expiryStatus = 'NON_EXPIRED',
        String applicant = 'Northwind Imports',
        String applicationDate = '2026-09-01T00:00:00',
        bool transferable = false,
        bool revolving = false}) =>
    CorpLetterOfCredit.fromJson(
      _lcJson(
        id,
        status: status,
        expiryStatus: expiryStatus,
        applicant: applicant,
        applicationDate: applicationDate,
        transferable: transferable,
        revolving: revolving,
      ),
    )!;

class _FakeRepository implements CorpTradeFinanceRepository {
  _FakeRepository({this.list = const [], this.detail});

  final List<CorpLetterOfCredit> list;
  final CorpLetterOfCredit? detail;
  final List<Map<String, dynamic>> queries = [];

  @override
  Future<ResponseHandler<List<CorpLetterOfCredit>>> searchExportLetterOfCredits(
    Map<String, dynamic> query,
  ) async {
    queries.add(query);
    return ResponseHandler.success(list, code: 200);
  }

  @override
  Future<ResponseHandler<CorpLetterOfCredit>> fetchLetterOfCredit(
    String id, {
    String? versionNo,
  }) async =>
      ResponseHandler.success(detail!, code: 200);

  @override
  Future<ResponseHandler<List<CorpLcAmendment>>> fetchExportAmendments({
    String? partyId,
  }) async =>
      ResponseHandler.success(
        CorpLcAmendment.listFromPayload({
          'letterOfCreditAmendmentDTOs': [
            {
              'id': '1',
              'lcId': 'EXP001',
              'newAmount': {'currency': 'GBP', 'amount': 250000},
              'applicantName': 'Northwind Imports',
            },
            {
              'id': '4',
              'lcId': 'OTHER',
              'newAmount': {'currency': 'GBP', 'amount': 1}
            },
          ],
        }),
        code: 200,
      );

  @override
  Future<ResponseHandler<TradeBank?>> lookupBic(String swiftCode) async =>
      ResponseHandler.success(
        swiftCode == 'CITIGB2LXXX'
            ? TradeBank.listFromPayload({
                'listResponse': [
                  {'code': 'CITIGB2LXXX', 'branchName': 'Citibank London'},
                ],
              }).firstOrNull
            : null,
        code: 200,
      );

  /// Bills: one under EXP001, one under another LC.
  @override
  Future<ResponseHandler<List<CorpExportBill>>> searchExportBills(
    Map<String, dynamic> query,
  ) async =>
      ResponseHandler.success(
        CorpExportBill.listFromPayload({
          'billDTOs': [
            {
              'id': 'EB-1',
              'lcRefNo': 'EXP001',
              'contractStatus': 'ACTIVE',
              'counterPartyName': 'Northwind Imports',
              'amount': {'currency': 'GBP', 'amount': 45000},
            },
            {'id': 'EB-9', 'lcRefNo': 'OTHER', 'contractStatus': 'ACTIVE'},
          ],
        }),
        code: 200,
      );

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
  Widget child, {
  required _FakeRepository repository,
  double width = 1100,
  List<String>? pushed,
}) async {
  tester.view.physicalSize = Size(width, 1600);
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
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens a detail tab the way a user would: the tab bar scrolls, so the
/// tab is brought into view first.
Future<void> _openTab(WidgetTester tester, String tab) async {
  await tester.ensureVisible(find.text(tab));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tab));
  await tester.pumpAndSettle();
}

void main() {
  group('the search sent to the host', () {
    test('uses the captured parameters and formats', () {
      final q = ExportLcSearch(
        status: ExportLcStatus.active,
        drawingStatus: ExportLcDrawingStatus.partial,
        fromAmount: 1000,
        toAmount: 100000,
        expiryFrom: DateTime(2026, 10, 5),
        expiryTo: DateTime(2026, 10, 6),
        // Applied in the app, never sent:
        lcNumber: 'exp',
        applicantName: 'north',
        issueFrom: DateTime(2026),
        expiry: ExportLcExpiry.notExpired,
      ).toQuery(partyId: 'P1');
      expect(q, {
        'lcType': 'Export',
        'partyIds': 'P1',
        'lcStatus': 'ACTIVE',
        'status': 'PARTIAL',
        'fromAmount': 1000,
        'toAmount': 100000,
        'expiryDatefrom': '2026-10-05',
        'expiryDateto': '2026-10-06',
      });
    });

    test('with no filters, just the export list for the party', () {
      expect(ExportLcSearch.none.toQuery(partyId: 'P1'), {
        'lcType': 'Export',
        'partyIds': 'P1',
      });
      expect(ExportLcSearch.none.isEmpty, isTrue);
    });
  });

  group('the filters applied in the app', () {
    final lc = _lc('EXP001', applicant: 'Northwind Imports');

    test('LC number and applicant, case-insensitive, partial', () {
      expect(const ExportLcSearch(lcNumber: 'exp0').matches(lc), isTrue);
      expect(const ExportLcSearch(lcNumber: 'zzz').matches(lc), isFalse);
      expect(const ExportLcSearch(applicantName: 'NORTH').matches(lc), isTrue);
      expect(const ExportLcSearch(applicantName: 'acme').matches(lc), isFalse);
    });

    test('issue date range, inclusive of both days', () {
      expect(
        ExportLcSearch(
                issueFrom: DateTime(2026, 9, 1), issueTo: DateTime(2026, 9, 1))
            .matches(lc),
        isTrue,
      );
      expect(
          ExportLcSearch(issueFrom: DateTime(2026, 9, 2)).matches(lc), isFalse);
    });

    test('expired or not', () {
      final expired = _lc('EXP002', expiryStatus: 'EXPIRED');
      const onlyExpired = ExportLcSearch(expiry: ExportLcExpiry.expired);
      expect(onlyExpired.matches(expired), isTrue);
      expect(onlyExpired.matches(lc), isFalse);
    });

    test('each filter comes off on its own; ranges as a whole', () {
      final s = ExportLcSearch(
        status: ExportLcStatus.active,
        fromAmount: 1,
        toAmount: 2,
      );
      expect(s.activeFilters, [ExportLcFilter.status, ExportLcFilter.amount]);
      final less = s.without(ExportLcFilter.amount);
      expect(less.fromAmount, isNull);
      expect(less.toAmount, isNull);
      expect(less.status, ExportLcStatus.active);
    });
  });

  test('detail fields read from the captured LC detail', () {
    final lc = _lc('EXP001', revolving: true);
    expect(lc.totalExposure?.amount, 210000);
    expect(lc.revolvingFrequency, '3 months');
    expect(lc.autoReinstatement, isTrue);
    expect(lc.cumulative, isFalse);
    expect(lc.partyAddress.city, 'London');
    expect(lc.paymentConditionsBeneficiary, 'Pay on first presentation');
    expect(lc.requestedConfirmationParty, 'Advising Bank Ltd');
    // No document list in the captures: none, not invented.
    expect(lc.exportDocuments, isEmpty);
  });

  test('a document list, when the host sends one', () {
    final lc = CorpLetterOfCredit.fromJson({
      ..._lcJson('EXP009'),
      'documents': [
        {
          'name': 'Commercial invoice',
          'numberOfOriginals': '2/3',
          'numberOfCopies': '1',
          'clauses': [
            {'code': 'C1', 'description': 'Signed by the beneficiary'},
          ],
        },
      ],
    })!;
    final doc = lc.exportDocuments.single;
    expect(doc.name, 'Commercial invoice');
    expect(doc.originals, '2/3');
    expect(doc.clauses, ['Signed by the beneficiary']);
  });

  group('the results page', () {
    final items = [
      _lc('EXP001', applicant: 'Northwind Imports'),
      _lc('EXP002', applicant: 'Fabrikam Trading', expiryStatus: 'EXPIRED'),
    ];

    testWidgets('a table on a wide screen', (tester) async {
      await _pump(
        tester,
        const ExportLcListPage(),
        repository: _FakeRepository(list: items),
      );
      expect(find.text('2 export LCs'), findsOneWidget);
      expect(find.text('Date of expiry'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('Northwind Imports'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cards on a phone', (tester) async {
      await _pump(
        tester,
        const ExportLcListPage(),
        repository: _FakeRepository(list: items),
        width: 380,
      );
      expect(find.text('Applicant: Northwind Imports'), findsOneWidget);
      expect(find.text('Date of expiry'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening an LC goes to the export detail', (tester) async {
      final pushed = <String>[];
      await _pump(
        tester,
        const ExportLcListPage(),
        repository: _FakeRepository(list: items),
        width: 380,
        pushed: pushed,
      );
      await tester.tap(find.text('EXP001'));
      await tester.pumpAndSettle();
      expect(pushed, contains(CorpRoutesConst.exportLcDetailScreen));
    });

    testWidgets('filters from the sheet go to the host, and come off as chips',
        (tester) async {
      final repository = _FakeRepository(list: items);
      await _pump(
        tester,
        const ExportLcListPage(),
        repository: repository,
        width: 380,
      );
      await tester.tap(find.byTooltip('Search & filter'));
      await tester.pumpAndSettle();
      // A phone: the sheet.
      expect(find.text('Search export LCs'), findsOneWidget);

      await tester.tap(find.text('Partial'));
      await tester.pump();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(repository.queries.last['status'], 'PARTIAL');
      expect(find.text('Drawing: Partial'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove filter'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.containsKey('status'), isFalse);
    });

    testWidgets('the form refuses a range that ends before it starts',
        (tester) async {
      await _pump(
        tester,
        const ExportLcListPage(),
        repository: _FakeRepository(list: items),
      );
      await tester.tap(find.byTooltip('Search & filter'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'LC amount from'),
        '500',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'LC amount to'),
        '100',
      );
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(
        find.text('The "from" amount is more than the "to" amount.'),
        findsOneWidget,
      );
    });
  });

  group('the detail screen', () {
    Future<void> pumpDetail(
      WidgetTester tester, {
      required CorpLetterOfCredit lc,
      double width = 1100,
    }) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            corpTradeFinanceRepositoryProvider
                .overrideWithValue(_FakeRepository(detail: lc)),
            lcPermissionsProvider.overrideWithValue(_allowed),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: ExportLcDetailScreen(
              args: LcDetailArgs(lcId: lc.id, lcType: LcType.exportLc),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the manual\'s tabs, LC details first', (tester) async {
      await pumpDetail(tester, lc: _lc('EXP001'));
      for (final t in ExportLcDetailScreen.tabs) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Party name and ID'), findsOneWidget);
      expect(find.text('Contoso Exports · ***001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('more information opens and closes', (tester) async {
      await pumpDetail(tester, lc: _lc('EXP001'));
      expect(find.text('Total exposure'), findsNothing);
      await tester.tap(find.text('More information'));
      await tester.pumpAndSettle();
      expect(find.text('Total exposure'), findsOneWidget);
      expect(find.text('Sight payment'), findsOneWidget);
    });

    testWidgets('amendments: only this LC\'s', (tester) async {
      await pumpDetail(tester, lc: _lc('EXP001'));
      await _openTab(tester, 'Amendments');
      expect(find.text('Amendment 1'), findsOneWidget);
      expect(find.text('Amendment 4'), findsNothing);
    });

    testWidgets("bills: only this LC's", (tester) async {
      await pumpDetail(tester, lc: _lc('EXP001'));
      await _openTab(tester, 'Bills');
      expect(find.text('EB-1'), findsOneWidget);
      expect(find.text('EB-9'), findsNothing);
    });

    testWidgets('banks: names looked up by SWIFT code', (tester) async {
      await pumpDetail(tester, lc: _lc('EXP001'));
      await _openTab(tester, 'Banks');
      expect(find.text('Citibank London'), findsOneWidget);
      // Unknown to the host: the code alone.
      expect(find.text('BANKAEADXXX'), findsOneWidget);
    });

    testWidgets('a transferable active LC offers Transfer in the ⋮ menu',
        (tester) async {
      await pumpDetail(tester, lc: _lc('EXP001', transferable: true));
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(find.text('Transfer LC'), findsOneWidget);
      await pumpDetail(tester, lc: _lc('EXP003'));
      expect(find.byTooltip('More actions'), findsNothing);
    });

    // An LC whose detail says Import, like 000ILUN20076AD49 in the
    // captures, with a back-to-back LC.
    final importLc = CorpLetterOfCredit.fromJson({
      ..._lcJson('IMP001'),
      'lcType': 'Import',
      'parentReferenceLCs': ['123'],
    })!;

    testWidgets('the OBDX heading: title, party, header strip', (tester) async {
      await pumpDetail(tester, lc: importLc);
      expect(find.text('View Import Letter Of Credit'), findsOneWidget);
      expect(find.text('Contoso Exports | ***001'), findsOneWidget);
      expect(find.text('LC Reference No.'), findsOneWidget);
      expect(find.text('IMP001'), findsWidgets);
      expect(find.text('Back to Back LC No.'), findsOneWidget);
      expect(find.text('123'), findsOneWidget);
      expect(find.text('Date of Expiry'), findsOneWidget);
      expect(find.text('Export LC'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Copy & Initiate and Back at the bottom', (tester) async {
      await pumpDetail(tester, lc: importLc);
      expect(find.text('Copy & Initiate'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('an export LC: no Copy & Initiate, just Back', (tester) async {
      await pumpDetail(tester, lc: _lc('EXP001'));
      expect(find.text('View Export Letter Of Credit'), findsOneWidget);
      expect(find.text('Copy & Initiate'), findsNothing);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('the heading and buttons fit a phone', (tester) async {
      // 390: the test font is far wider than the app's.
      await pumpDetail(tester, lc: importLc, width: 390);
      expect(find.text('Import Letter of Credit'), findsOneWidget);
      expect(find.text('Copy & Initiate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a phone in every tab', (tester) async {
      await pumpDetail(tester, lc: _lc('EXP001', revolving: true), width: 360);
      // A heading each tab shows, to prove the tab really opened.
      const shows = {
        'LC Details': 'Party name and ID',
        'Goods & Shipment': 'Port of loading / airport of departure',
        'Documents': 'Documents to present',
        'Instructions': 'Advising bank SWIFT ID',
        'Amendments': 'Amendments awaiting your acceptance',
        'Bills': 'Bills under this LC',
        'Charges': 'Charges, commission & taxes',
        'Banks': 'Issuing bank',
      };
      for (final t in ExportLcDetailScreen.tabs) {
        await _openTab(tester, t);
        expect(find.text(shows[t]!), findsOneWidget, reason: t);
        expect(tester.takeException(), isNull, reason: t);
      }
    });
  });
}
