import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/models/corp/corp_cash_collection.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loan_application.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loan_record.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account_details.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_cash_management_api.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_process_management_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_cash_management_repository.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_lending_repository.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_widget_data_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_withdrawal_live_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_live_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_live_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_live_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_live_widgets.dart';

// ── Fakes returning the widgets capture's responses ─────────────────────

Map<String, dynamic> _wrapped(int statusCode, Map<String, dynamic> body) =>
    {'statusCode': statusCode, 'body': body};

class _FakeProcessApi implements ObdxCorpProcessManagementApi {
  _FakeProcessApi(this.body);

  final Map<String, dynamic> body;
  String? partyId;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchProcesses({
    required String partyId,
    String moduleId = 'OBCLPM',
  }) async {
    this.partyId = partyId;
    return ResponseHandler.success(_wrapped(200, body));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCashApi implements ObdxCorpCashManagementApi {
  _FakeCashApi(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
  String? type;
  String? interval;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchCashCollections({
    required String transactionType,
    required String interval,
    required DateTime from,
    required DateTime to,
  }) async {
    type = transactionType;
    this.interval = interval;
    return ResponseHandler.success(_wrapped(statusCode, body));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Test data ───────────────────────────────────────────────────────────

MoneyAmount _gbp(double amount) => MoneyAmount(amount: amount, currency: 'GBP');

CorpLoanRecord _loan(
  String id, {
  required double sanctioned,
  required double outstanding,
  String product = 'Home Finance',
  String currency = 'GBP',
  double? rate,
  DateTime? nextDue,
  double? nextAmount,
  DateTime? maturity,
  bool withDetails = true,
}) {
  return CorpLoanRecord(
    account: LoanAccount(
      id: id,
      displayNumber: 'xxxx$id',
      currencyCode: currency,
      productName: product,
      holderName: 'ACME Ltd',
      status: 'ACTIVE',
      sanctionedAmount: MoneyAmount(amount: sanctioned, currency: currency),
      outstandingAmount: MoneyAmount(amount: outstanding, currency: currency),
    ),
    details: withDetails
        ? LoanAccountDetails(
            id: id,
            displayNumber: 'xxxx$id',
            interestRate: rate,
            maturityDate: maturity,
            nextDueDate: nextDue,
            nextInstallmentAmount: nextAmount == null ? null : _gbp(nextAmount),
          )
        : null,
  );
}

final _today = DateTime(2026, 9, 24);

void main() {
  group('the captured responses', () {
    test('no loan applications: an empty list, not a failure', () async {
      final api = _FakeProcessApi({
        'status': {
          'result': 'SUCCESSFUL',
          'message': {'type': 'INFO'}
        },
        'processManagementDTOs': [],
      });
      final result = await CorpLendingRepository(processManagementApi: api)
          .fetchLoanApplications('PARTY1');
      expect(result, isA<Success<List<CorpLoanApplication>>>());
      expect((result as Success<List<CorpLoanApplication>>).data, isEmpty);
      expect(api.partyId, 'PARTY1');
    });

    test('the CW refusal (DATE006) is a failure the widget can show', () async {
      final api = _FakeCashApi(400, {
        'result': 'SUCCESSFUL',
        'message': {
          'title': 'System cannot process the request currently.',
          'code': 'DIGX_PROD_DEF_0000',
          'relatedMessage': [
            {'detail': 'The date is not valid.', 'code': 'DATE006'},
          ],
          'type': 'ERROR',
        },
      });
      final result = await CorpCashManagementRepository(cashManagementApi: api)
          .fetchCashWithdrawals(
        from: DateTime(2026, 9),
        to: DateTime(2026, 9, 30),
      );
      expect(result, isA<Error<List<CorpCashCollectionEntry>>>());
      // The same call the web client makes: type CW, by month.
      expect(api.type, 'CW');
      expect(api.interval, 'M');
    });

    test('no deposits: an empty list', () {
      expect(
        CorpAccount.listFromPayload(
          {
            'status': {'result': 'SUCCESSFUL'},
            'accounts': []
          },
          groupOverride: CorpAccountGroup.deposit,
        ),
        isEmpty,
      );
    });
  });

  group('reading fields not captured yet', () {
    test('a deposit\'s maturity date and rate', () {
      final account = CorpAccount.listFromPayload(
        {
          'accounts': [
            {
              'id': {'value': 'TD1', 'displayValue': 'xxxx0001'},
              'status': 'ACTIVE',
              'currencyCode': 'GBP',
              'principalAmount': {'amount': 120000, 'currency': 'GBP'},
              'maturityAmount': {'amount': 128100, 'currency': 'GBP'},
              'maturityDate': '2026-10-15T00:00:00',
              'interestRate': 6.75,
            },
          ],
        },
        groupOverride: CorpAccountGroup.deposit,
      ).single;
      expect(account.maturityDate, DateTime(2026, 10, 15));
      expect(account.interestRate, 6.75);
    });

    test('cash collection entries from the first list in the body', () {
      final entries = CorpCashCollectionEntry.listFromPayload({
        'status': {'result': 'SUCCESSFUL'},
        'collectionDTOs': [
          {
            'date': '2026-09-01',
            'amount': {'amount': 96400, 'currency': 'GBP'},
            'channel': 'ATM',
            'count': 12,
          },
          {
            'date': '2026-09-01',
            'amount': {'amount': 149600, 'currency': 'GBP'},
            'channel': 'Branch',
            'count': 20,
          },
        ],
      });
      expect(entries, hasLength(2));
      final book = CorpWithdrawalBook(
        entries: entries,
        month: DateTime(2026, 9),
      ).toData();
      expect(book.total, 246000);
      expect(book.transactions, 32);
      expect([for (final c in book.byChannel) c.label], ['ATM', 'Branch']);
      // Not in the entries, so not invented.
      expect(book.largest, isNull);
      expect(book.availableLimit, isNull);
    });

    test('an application, and its stage on the tracker', () {
      final app = CorpLoanApplication.listFromPayload({
        'processManagementDTOs': [
          {
            'applicationId': 'LF-2026-0842',
            'productName': 'Term Loan',
            'requestedAmount': {'amount': 50000, 'currency': 'GBP'},
            'stage': 'Credit Assessment',
            'creationDate': '2026-09-18T10:00:00',
          },
        ],
      }).single;
      final data = CorpLoanApplicationMapping.toData(app);
      expect(data.applicationId, 'LF-2026-0842');
      expect(data.currentStep, 2);
      expect(data.requestedAmount, 50000);
      expect(CorpLoanApplicationMapping.stepFor('DISBURSED'), 4);
      expect(CorpLoanApplicationMapping.stepFor('Something new'), 0);
    });
  });

  group('the loan figures', () {
    final book = CorpLoanBook(
      today: _today,
      records: [
        _loan(
          '1',
          sanctioned: 500000,
          outstanding: 300000,
          rate: 7,
          nextDue: DateTime(2026, 9, 26),
          nextAmount: 10000,
          maturity: DateTime(2030, 5, 24),
        ),
        _loan(
          '2',
          sanctioned: 200000,
          outstanding: 100000,
          product: 'Auto Finance',
          rate: 9,
          nextDue: DateTime(2026, 9, 20),
          nextAmount: 4000,
          maturity: DateTime(2027, 1, 1),
        ),
        // Due beyond the window — not listed.
        _loan(
          '3',
          sanctioned: 50000,
          outstanding: 50000,
          product: 'Auto Finance',
          nextDue: DateTime(2026, 11, 1),
          nextAmount: 1000,
        ),
        // Another currency — left out of every figure.
        _loan('4', sanctioned: 1, outstanding: 1, currency: 'AED'),
      ],
    );

    test('one currency, the one most loans are in', () {
      expect(book.currency, 'GBP');
      expect(book.records, hasLength(3));
    });

    test('summary', () {
      final s = book.summary();
      expect(s.totalLoan, 750000);
      expect(s.outstanding, 450000);
      expect(s.nextEmi, 15000);
      // Outstanding-weighted: (300k × 7 + 100k × 9) / 400k.
      expect(s.interestRate, closeTo(7.5, 1e-9));
      expect(s.remainingTenureMonths, 44); // to May 2030
    });

    test('portfolio mix by product, as shares of what is outstanding', () {
      final p = book.portfolio();
      expect(p.activeLoans, 3);
      expect(
          [for (final m in p.mix) m.label], ['Home Finance', 'Auto Finance']);
      expect(p.mix.first.share, closeTo(300000 / 450000 * 100, 1e-9));
      expect(p.nextReview, isNull);
    });

    test('instalments overdue or due within ten days', () {
      final due = book.installments();
      expect([
        for (final i in due) i.status
      ], [
        CorpInstallmentStatus.dueSoon,
        CorpInstallmentStatus.overdue,
      ]);
    });

    test('a loan whose details failed keeps its balances, not a rate', () {
      final partial = CorpLoanBook(
        today: _today,
        records: [
          _loan('9', sanctioned: 100, outstanding: 60, withDetails: false),
        ],
      );
      expect(partial.summary().outstanding, 60);
      expect(partial.summary().interestRate, isNull);
      expect(partial.accountRows().single.maturity, isNull);
    });
  });

  test('deposits: open ones, in the main currency', () {
    CorpAccount deposit(String id, String status, String currency) =>
        CorpAccount(
          id: id,
          displayNumber: id,
          status: status,
          currencyCode: currency,
          group: CorpAccountGroup.deposit,
          principalAmount: MoneyAmount(amount: 100, currency: currency),
        );
    final book = CorpTdBook([
      deposit('a', 'ACTIVE', 'GBP'),
      deposit('b', 'ACTIVE', 'GBP'),
      deposit('c', 'CLOSED', 'GBP'),
      deposit('d', 'ACTIVE', 'USD'),
    ]);
    expect(book.currency, 'GBP');
    expect([for (final d in book.deposits) d.id], ['a', 'b']);
    // No maturity value reported: the principal.
    expect(book.deposits.first.maturityValue, 100);
  });

  test('the registry builds the live widgets for the captured components', () {
    const registry = CorpWidgetRegistry();
    expect(
      registry.builders['loan-summary']!(),
      isA<CorpLiveLoanSummaryWidget>(),
    );
    expect(registry.builders['td-summary']!(), isA<CorpLiveTdSummaryWidget>());
  });

  group('a live widget shows', () {
    Future<void> pump(
      WidgetTester tester,
      Widget widget,
      List<Override> overrides,
    ) async {
      tester.view.physicalSize = const Size(700, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(width: 600, child: widget),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('loading while the data is on its way', (tester) async {
      await pump(tester, const CorpLiveLoanSummaryWidget(), [
        corpLoanRecordsProvider.overrideWith(
          (ref) => Completer<({List<CorpLoanRecord> records, DateTime today})>()
              .future,
        ),
      ]);
      await tester.pump();
      expect(find.text('Loan Summary'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('the host\'s message and a Retry that loads again',
        (tester) async {
      var calls = 0;
      await pump(tester, const CorpLiveLoanSummaryWidget(), [
        corpLoanRecordsProvider.overrideWith((ref) async {
          calls++;
          throw const CorpWidgetLoadError('The date is not valid.');
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('The date is not valid.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets('a plain message when there is nothing, never sample figures',
        (tester) async {
      await pump(tester, const CorpLiveLoanSummaryWidget(), [
        corpLoanRecordsProvider.overrideWith(
          (ref) async => (records: <CorpLoanRecord>[], today: _today),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(
          find.text('You have no loan or finance accounts.'), findsOneWidget);
      expect(find.byType(CorpSampleDataTag), findsNothing);
      expect(find.text('£824K'), findsNothing);
    });

    testWidgets('the data, in its own currency, without the sample tag',
        (tester) async {
      await pump(tester, const CorpLiveLoanSummaryWidget(), [
        corpLoanRecordsProvider.overrideWith(
          (ref) async => (
            records: [
              _loan('1',
                  sanctioned: 500000,
                  outstanding: 300000,
                  currency: 'AED',
                  rate: 7),
            ],
            today: _today,
          ),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('AED 300K'), findsOneWidget);
      expect(find.text('7.00%'), findsOneWidget);
      expect(find.byType(CorpSampleDataTag), findsNothing);
    });

    testWidgets('term deposits: none', (tester) async {
      await pump(tester, const CorpLiveTdSummaryWidget(), [
        corpDepositsProvider.overrideWith((ref) async => <CorpAccount>[]),
        corpBusinessDateProvider.overrideWith((ref) async => _today),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('You have no term deposits.'), findsOneWidget);
    });

    testWidgets('loan sample figures stay out of the live tracker',
        (tester) async {
      await pump(tester, const CorpLiveLoanApplicationTrackerWidget(), [
        corpLoanApplicationsProvider.overrideWith(
          (ref) async => <CorpLoanApplication>[],
        ),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.text('You have no loan applications in progress.'),
        findsOneWidget,
      );
      expect(
        find.text(CorpLoanSampleData.application.applicationId),
        findsNothing,
      );
    });
  });
}
