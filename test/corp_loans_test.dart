import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_bank/l10n/app_localizations.dart';
import 'package:demo_bank/src/core/config/locale_config.dart';
import 'package:demo_bank/src/core/models/common/obdx_challenge.dart';
import 'package:demo_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:demo_bank/src/core/models/common/service_requests/service_request_models.dart';
import 'package:demo_bank/src/core/models/corp/corp_loans_models.dart';
import 'package:demo_bank/src/core/theme/app_theme.dart';
import 'package:demo_bank/src/infra/network/response_handler.dart';
import 'package:demo_bank/src/infra/repositories/corp/corp_loans_repository.dart';
import 'package:demo_bank/src/view/providers/corp/corp_loans_providers.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_loan_application_tracker_screen.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_loan_notices_screen.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_loan_transactions_screen.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_loans_hub_screen.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_multi_loan_repayment_screen.dart';

// Field names follow OBDX obcl-* model.js; values are made up.

final _loans = CorpLoan.listFromPayload({
  'accounts': [
    {
      'id': {'value': 'L1', 'displayValue': 'xxxx0001'},
      'currencyCode': 'GBP',
      'productDTO': {'name': 'Term Loan'},
      'approvedAmount': {'amount': 50000, 'currency': 'GBP'},
      'outstandingAmount': {'amount': 12000, 'currency': 'GBP'},
      'valueDate': '2024-01-15',
      'maturityDate': '2027-01-15',
    },
  ],
});

class _FakeRepo extends Fake implements CorpLoansRepository {
  final deleted = <String>[];
  final repaid = <CorpRepaymentLine>[];
  var drafts = [
    const CorpLoanApplicationItem(refId: 'APP1', type: 'Loan Drawdown', status: 'DRAFT', draftName: 'Expansion'),
    const CorpLoanApplicationItem(refId: 'APP2', type: 'Trade Loan Drawdown', status: 'DRAFT', draftName: 'Imports'),
  ];

  @override
  Future<ResponseHandler<List<CorpLoan>>> fetchLoans() async => Success(_loans);

  @override
  Future<ResponseHandler<List<CorpLoan>>> fetchContracts(CorpLoanContractFilter filter, {DateTime? today}) async => Success(_loans);

  @override
  Future<ResponseHandler<({List<CorpLoanTxn> items, bool showValueDate})>> fetchTransactions(
    String loanId,
    CorpLoanTxnQuery query, {
    DateTime? today,
  }) async =>
      Success(CorpLoanTxn.fromPayload({
        'showValueDate': true,
        'items': [
          {
            'postingDate': '2026-10-02',
            'valueDate': '2026-10-02',
            'description': 'Principal Repayment',
            'transactionType': 'C',
            'key': {'transactionReferenceNumber': 'TRN77'},
            'amountInAccountCurrency': {'amount': 900, 'currency': 'GBP'},
          },
        ],
      }));

  @override
  Future<ResponseHandler<List<CorpLoanNotice>>> fetchNotices(String loanId, CorpLoanNoticeKind kind) async =>
      Success(CorpLoanNotice.listFromPayload({
        'swiftMessages': [
          {'messageId': 'MSG9', 'date': '2026-09-01', 'description': 'Booking', 'messageType': 'MT320', 'message': 'FULL TEXT'},
        ],
      }));

  @override
  Future<ResponseHandler<String>> generateBulkReference() async => Success('BULK42');

  @override
  Future<ResponseHandler<List<SrAccount>>> fetchSourceAccounts() async => Success(const [SrAccount(value: 'C1', displayValue: 'xxxx9001')]);

  @override
  Future<ResponseHandler<PrefWriteOutcome>> repay(CorpRepaymentLine line, String bulkReference,
      {ObdxChallenge? challenge, String? otp}) async {
    repaid.add(line);
    return Success(const PrefWriteOutcome.done(reference: 'HOST1'));
  }

  @override
  Future<ResponseHandler<List<CorpLoanApplicationItem>>> fetchApplications(CorpAppStatus status, {String? partyId}) async =>
      Success(status == CorpAppStatus.draft ? drafts : const []);

  @override
  Future<ResponseHandler<List<CorpAppDocument>>> fetchDocuments(String refId, String partyId) async =>
      Success(const [CorpAppDocument(contentId: 'D1', title: 'board_resolution.pdf')]);

  @override
  Future<ResponseHandler<bool>> deleteDraft(String refId) async {
    deleted.add(refId);
    drafts = [
      for (final d in drafts)
        if (d.refId != refId) d
    ];
    return Success(true);
  }
}

void main() {
  group('models', () {
    final today = DateTime(2026, 10, 30);

    test('transactions query: ranges worked out, Last 10, amount and reference', () {
      expect(const CorpLoanTxnQuery(period: CorpLoanPeriod.currentDay).toQuery(today),
          {'transactionType': 'A', 'searchBy': 'SPD', 'fromDate': '2026-10-30', 'toDate': '2026-10-30'});
      expect(const CorpLoanTxnQuery(period: CorpLoanPeriod.currentAndPreviousMonth).toQuery(today)['fromDate'], '2026-09-01');
      expect(const CorpLoanTxnQuery(period: CorpLoanPeriod.lastTen).toQuery(today),
          {'transactionType': 'A', 'searchBy': 'LNT', 'noOfTransactions': 10});
      final q = const CorpLoanTxnQuery(type: CorpLoanTxnType.debits, amount: 25, reference: ' R1 ').toQuery(today);
      expect(q, {'transactionType': 'D', 'searchBy': 'CPR', 'fromAmount': 25.0, 'toAmount': 25.0, 'referenceNo': 'R1'});
    });

    test('loans and transactions parse', () {
      expect(_loans.single.title, 'Term Loan · xxxx0001');
      expect(_loans.single.outstanding!.amount, 12000);
      final t = CorpLoanTxn.fromPayload({
        'items': [
          {
            'postingDate': '2026-10-02',
            'description': 'X',
            'transactionType': 'D',
            'amount': {'amount': 5}
          },
        ],
      });
      expect(t.showValueDate, isFalse);
      expect(t.items.single.isCredit, isFalse);
      expect(t.items.single.amount!.amount, 5);
    });

    test('a repayment is sent in the loan currency with its own allocation', () {
      final c = CorpRepaymentComponent.listFromPayload({
        'components': [
          {
            'component': 'PRINCIPAL',
            'componentDescription': 'Principal',
            'amountDue': {'amount': 10},
            'amountPaid': {'amount': 10}
          },
        ],
      });
      final body = CorpRepaymentLine(
        loan: _loans.single,
        amount: 100,
        principalAccount: const {'value': 'C1', 'displayValue': 'xxxx9001'},
        components: c,
      ).toBody('BULK42');
      expect(body['amount'], {'amount': 100.0, 'currency': 'GBP'});
      expect(body['interestSettlementAccountId'], body['settlementAccountId']);
      expect(body['bulkReferenceNumber'], 'BULK42');
      expect(body['maturityDate'], '2027-01-15');
      expect((body['repaymentSimulations'] as List).single['component'], 'PRINCIPAL');
    });

    test('contract filter sends only what is set', () {
      expect(CorpLoanContractFilter(currency: 'GBP', maturityTo: DateTime(2027)).toQuery(today),
          {'applicationDate': '2026-10-30', 'currencyCode': 'GBP', 'maturityToDate': '2027-01-01'});
    });
  });

  group('screens', () {
    late _FakeRepo repo;

    Future<void> pump(WidgetTester tester, Widget Function(VoidCallback back) screen, {double width = 1200}) async {
      repo = _FakeRepo();
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            corpLoansRepositoryProvider.overrideWithValue(repo),
            corpLoansPartyIdProvider.overrideWith((ref) async => 'P001'),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: Scaffold(body: screen(() {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pickLoan(WidgetTester tester) async {
      await tester.tap(find.text('Please Select').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('xxxx0001').last);
      await tester.pumpAndSettle();
    }

    testWidgets('hub lists the five functions', (tester) async {
      Widget? opened;
      await pump(
        tester,
        (back) => CorpLoansHubScreen(open: (page) => opened = page(() {})),
      );
      expect(find.text('Corporate Loans & Finances'), findsOneWidget);
      expect(find.text('Loans'), findsNothing);
      for (final t in ['Transactions', 'Messages', 'Advices', 'Multiple Loan Repayment', 'Application Tracker']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await tester.tap(find.text('Advices'));
      expect(opened, isA<CorpLoanNoticesScreen>());
      expect((opened! as CorpLoanNoticesScreen).kind, CorpLoanNoticeKind.advice);
    });

    testWidgets('transactions: a loan is required; Apply shows the statement', (tester) async {
      await pump(tester, (back) => CorpLoanTransactionsScreen(onBack: back));
      expect(find.text('Current Month'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Please select a loan account.'), findsOneWidget);

      await pickLoan(tester);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Value Date'), findsOneWidget);
      expect(find.text('Principal Repayment'), findsOneWidget);
      expect(find.text('TRN77'), findsOneWidget);
      expect(find.text('Credit'), findsOneWidget);

      // The filter goes back to the search.
      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('messages: rows for the loan; the id opens the message', (tester) async {
      await pump(tester, (back) => CorpLoanNoticesScreen(kind: CorpLoanNoticeKind.message, onBack: back));
      expect(find.text('Corporate Loans - Messages'), findsOneWidget);
      await pickLoan(tester);
      expect(find.text('MT320'), findsOneWidget);
      expect(find.byTooltip('Download'), findsOneWidget);
      await tester.tap(find.text('MSG9'));
      await tester.pumpAndSettle();
      expect(find.text('FULL TEXT'), findsOneWidget);
    });

    testWidgets('repayment: contracts, validation, review and result', (tester) async {
      await pump(tester, (back) => CorpMultiLoanRepaymentScreen(onBack: back));
      expect(find.text('BULK42'), findsOneWidget);
      expect(find.text('P001'), findsOneWidget);

      await tester.tap(find.text('Get Contracts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Please select the principal source account.'), findsOneWidget);

      await tester.tap(find.text('Please Select').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('xxxx9001').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('You initiated a request for Multiple Loan Repayment'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repo.repaid.single.amount, 12000);
      expect(repo.repaid.single.principalAccount['value'], 'C1');
      expect(find.text('HOST1'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);
    });

    testWidgets('every screen lays out on a phone', (tester) async {
      for (final screen in <Widget Function(VoidCallback)>[
        (b) => CorpLoanTransactionsScreen(onBack: b),
        (b) => CorpLoanNoticesScreen(kind: CorpLoanNoticeKind.advice, onBack: b),
        (b) => CorpMultiLoanRepaymentScreen(onBack: b),
        (b) => CorpLoanApplicationTrackerScreen(onBack: b),
      ]) {
        await pump(tester, screen, width: 380);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();
      expect(find.text('Expansion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tracker: drafts listed, search narrows, delete asks first', (tester) async {
      await pump(tester, (back) => CorpLoanApplicationTrackerScreen(onBack: back));
      expect(find.text('Expansion'), findsOneWidget);
      expect(find.text('Imports'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'imp');
      await tester.pumpAndSettle();
      expect(find.text('Expansion'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to delete the draft application named Expansion ?'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['APP1']);
      expect(find.text('The draft application named Expansion has been deleted successfully.'), findsOneWidget);
      expect(find.text('Imports'), findsOneWidget);

      await tester.tap(find.text('Imports'));
      await tester.pumpAndSettle();
      expect(find.text('Application Details'), findsOneWidget);
      expect(find.text('Trade Loan Drawdown'), findsOneWidget);
      expect(find.text('board_resolution.pdf'), findsOneWidget);
    });
  });
}
