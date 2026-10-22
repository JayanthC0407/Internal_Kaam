import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_payment_models.dart';
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
}

class _FakeRepo implements BillPaymentsRepository {
  _FakeRepo(this.rows);

  final List<BillPayment> rows;
  final queries = <BillHistoryQuery>[];

  @override
  Future<ResponseHandler<List<BillPayment>>> fetchBillPayments(BillHistoryQuery query) async {
    queries.add(query);
    return ResponseHandler.success(rows, code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
