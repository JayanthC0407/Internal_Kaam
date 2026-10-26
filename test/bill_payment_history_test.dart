import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'dart:convert';

import 'package:ubci_bank/src/core/models/common/bill_payments/bill_payment_models.dart';
import 'package:ubci_bank/src/core/models/common/statement_format.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_bill_payments_api.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/bill_payments_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/bill_payment_history_screen.dart';

// Field names follow OBDX payment-history/hooks.js:321-338
// (docs/obdx/features/bill-payments.md §5.3); values are made up.

Map<String, dynamic> _payment(String id, String date, String status, {bool registration = true}) => {
      'id': id,
      'paymentDate': date,
      'billAmount': {'currency': 'GBP', 'amount': 12.5},
      'paymentStatus': status,
      if (registration)
        'billerRegistration': {
          'billerNickName': 'Home power $id',
          'category': {'name': 'Electricity'},
        }
      else ...{
        'billerName': 'Water Co',
        'category': 'Water',
      },
    };

void main() {
  group('model', () {
    test('rows read like OBDX: nickname/category from the registration, else the payment', () {
      final list = BillPayment.listFromPayload({
        'billPaymentDTOs': [
          _payment('P1', '2026-09-01T00:00:00', 'COM'),
          _payment('P2', '2026-10-05T00:00:00', 'ERR', registration: false),
          _payment('P3', '2026-10-01T00:00:00', 'XYZ'),
        ],
      });
      expect(list.map((p) => p.referenceNo), ['P2', 'P3', 'P1'], reason: 'newest first');
      expect(list.first.billerName, 'Water Co');
      expect(list.first.category, 'Water');
      expect(list.last.billerName, 'Home power P1');
      expect(list.last.category, 'Electricity');
      expect(list.last.status, BillPaymentStatus.completed);
      expect(list[1].status, BillPaymentStatus.unknown);
      expect(list[1].rawStatus, 'XYZ');
    });

    test('query: searchBy only, dates only for Date Range', () {
      expect(const BillHistoryQuery().toQueryParameters(), {'searchBy': 'CPR'});
      expect(
        const BillHistoryQuery(period: BillHistoryPeriod.previousQuarter).toQueryParameters(),
        {'searchBy': 'LQT'},
      );
      final range = BillHistoryQuery(
        period: BillHistoryPeriod.dateRange,
        from: DateTime(2026, 9, 3),
        to: DateTime(2026, 10, 1),
      );
      expect(range.toQueryParameters(), {'searchBy': 'SPD', 'fromDate': '2026-09-03', 'toDate': '2026-10-01'});
      expect(const BillHistoryQuery(period: BillHistoryPeriod.dateRange).isComplete, isFalse);
    });
  });

  Future<_FakeRepo> pump(WidgetTester tester, {double width = 390, List<BillPayment>? rows}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(rows ??
        BillPayment.listFromPayload({
          'billPaymentDTOs': [
            _payment('REF1', '2026-10-05T00:00:00', 'COM'),
            _payment('REF2', '2026-10-02T00:00:00', 'PND'),
          ],
        }));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [billPaymentsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleConfig.supportedLocales,
          home: const BillPaymentHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('phone: Current Period by default, rows with OBDX status labels', (tester) async {
    final repo = await pump(tester);
    expect(repo.queries.single.period, BillHistoryPeriod.currentPeriod);
    expect(find.text('Bill Payment History'), findsWidgets);
    expect(find.text('Current Period'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Reference No: REF1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Filter: Date Range needs both dates; Previous Month reloads with L1M', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date Range').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Select both dates.'), findsNWidgets(2));

    await tester.tap(find.text('Previous Month').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.period, BillHistoryPeriod.previousMonth);
    expect(find.text('Previous Month'), findsOneWidget);
  });

  testWidgets('empty: OBDX no-data text', (tester) async {
    await pump(tester, rows: const []);
    expect(find.text('No data found matching the search criteria'), findsOneWidget);
  });

  testWidgets('web: column headers like OBDX table', (tester) async {
    await pump(tester, width: 1280);
    for (final h in ['Date', 'Biller', 'Category', 'Bill Amount', 'Reference No', 'Status']) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
    expect(find.text('REF2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Download shows only with rows; PDF shows OBDX password note', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Password Combination'), findsOneWidget);
    expect(find.textContaining('ROOP2312'), findsOneWidget);
    await tester.tap(find.text('Download').last);
    await tester.pumpAndSettle();
    expect(repo.downloads.single.$2.code, 'pdf');
    expect(repo.downloads.single.$1.period, BillHistoryPeriod.currentPeriod);
  });

  testWidgets('no Download when there are no payments', (tester) async {
    await pump(tester, rows: const []);
    expect(find.byTooltip('Download'), findsNothing);
  });

  group('repository download (OBDX hooks.js:406-454)', () {
    test('formats: only CSV and PDF from the ebpp mediatype list', () async {
      final api = _FakeApi();
      final result = await BillPaymentsRepository(api: api).fetchHistoryFormats();
      expect((result as Success<List<StatementFormat>>).data!.map((f) => f.code), ['csv', 'pdf']);
    });

    test('download: current filter + media (MIME) + mediaFormat', () async {
      final api = _FakeApi();
      final query = BillHistoryQuery(
        period: BillHistoryPeriod.dateRange,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      final result = await BillPaymentsRepository(api: api)
          .downloadHistory(query, const StatementFormat(code: 'CSV', mimeType: 'text/csv'));
      expect(result, isA<Success<StatementFile>>());
      expect(api.downloadQuery, {'searchBy': 'SPD', 'fromDate': '2026-09-01', 'toDate': '2026-09-30'});
      expect(api.media, 'text/csv');
      expect(api.mediaFormat, 'csv');
    });
  });

}

class _FakeApi implements ObdxBillPaymentsApi {
  Map<String, dynamic>? downloadQuery;
  String? media;
  String? mediaFormat;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchHistoryMediaTypes() async {
    final body = {
      'enumRepresentations': [
        {
          'data': [
            {'code': 'csv', 'value': 'csv', 'description': 'text/csv', 'ordinal': 1},
            {'code': 'pdf', 'value': 'pdf', 'description': 'application/pdf', 'ordinal': 2},
            {'code': 'qif', 'value': 'qif', 'description': 'application/qif', 'ordinal': 3},
          ],
        },
      ],
    };
    return ResponseHandler.success({'statusCode': 200, 'headers': const {}, 'rawBody': jsonEncode(body), 'body': body});
  }

  @override
  Future<ResponseHandler<List<int>>> downloadBillPayments(
    Map<String, dynamic> queryParameters, {
    required String media,
    required String mediaFormat,
  }) async {
    downloadQuery = queryParameters;
    this.media = media;
    this.mediaFormat = mediaFormat;
    return ResponseHandler.success(utf8.encode('Date,Biller\n'), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo implements BillPaymentsRepository {
  _FakeRepo(this.rows);

  final List<BillPayment> rows;
  final queries = <BillHistoryQuery>[];
  final downloads = <(BillHistoryQuery, StatementFormat)>[];

  @override
  Future<ResponseHandler<List<StatementFormat>>> fetchHistoryFormats() async => ResponseHandler.success(
        const [
          StatementFormat(code: 'csv', mimeType: 'text/csv'),
          StatementFormat(code: 'pdf', mimeType: 'application/pdf'),
        ],
        code: 200,
      );

  @override
  Future<ResponseHandler<StatementFile>> downloadHistory(BillHistoryQuery query, StatementFormat format) async {
    downloads.add((query, format));
    return ResponseHandler.error(500, 'not saved in tests');
  }

  @override
  Future<ResponseHandler<List<BillPayment>>> fetchBillPayments(BillHistoryQuery query) async {
    queries.add(query);
    return ResponseHandler.success(rows, code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
