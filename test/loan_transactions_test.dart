import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/retail/account_transaction.dart';
import 'package:ubci_bank/src/core/models/retail/casa_transaction.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_loan_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/loan_repository.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/recent_transactions_widget_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_transaction_row.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_transactions_table.dart';

// `loan/{id}/transactions` items, in the shape OBDX returns them.
const _payload = {
  'items': [
    {
      'transactionDate': '2026-10-05T00:00:00',
      'amountInAccountCurrency': {'currency': 'GBP', 'amount': 887},
      'description': 'LOAN Principal Repayment',
      'userReferenceNumber': '000ZTRF2235609RX',
      'transactionType': 'D',
    },
    {
      'transactionDate': '2026-09-20T00:00:00',
      'amountInAccountCurrency': {'currency': 'GBP', 'amount': 50000},
      'description': 'Loan Disbursement',
      'transactionType': 'C',
    },
  ],
};

class _FakeLoanRepository implements LoanRepository {
  final queries = <CasaTransactionQuery>[];

  @override
  Future<ResponseHandler<List<AccountTransaction>>> fetchLoanTransactions(
    String loanId, {
    CasaTransactionQuery query = const CasaTransactionQuery(),
  }) async {
    queries.add(query);
    return ResponseHandler.success(AccountTransaction.listFromPayload(_payload), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the query parameters the API layer would send.
class _RecordingLoanApi implements ObdxLoanApi {
  Map<String, dynamic>? sent;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchLoanTransactions(
    String loanId, {
    int noOfTransactions = 5,
    Map<String, dynamic>? queryParameters,
  }) async {
    sent = queryParameters ?? {'searchBy': 'LNT', 'noOfTransactions': '$noOfTransactions'};
    return ResponseHandler.success({'statusCode': 200, 'body': _payload});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _accounts = [
  SelectableAccount(id: 'LN1', title: 'Home Loan', subtitle: 'xxxxxxxxxxxx0139'),
  SelectableAccount(id: 'LN2', title: 'Car Loan', subtitle: 'xxxxxxxxxxxx0456'),
];

Future<_FakeLoanRepository> _pump(WidgetTester tester, {double width = 390}) async {
  final repository = _FakeLoanRepository();
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loanRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleConfig.supportedLocales,
        home: const LoanTransactionsScreen(
          args: LoanTransactionsArgs(accounts: _accounts, initialAccountId: 'LN1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  group('Loan transactions – repository', () {
    test('Home keeps the last 5; the screen sends OBDX\'s filter', () async {
      final api = _RecordingLoanApi();
      final repository = LoanRepository(loanApi: api);

      await repository.fetchRecentLoanTransactions('LN1');
      expect(api.sent, {'searchBy': 'LNT', 'noOfTransactions': '5'});

      await repository.fetchLoanTransactions(
        'LN1',
        query: const CasaTransactionQuery(
          creditDebit: CasaCreditDebitFilter.debits,
          fromAmount: '887',
          toAmount: '887',
          referenceNumber: 'REF1',
        ),
      );
      expect(api.sent, {
        'searchBy': 'CPR',
        'transactionType': 'D',
        'fromAmount': '887',
        'toAmount': '887',
        'referenceNo': 'REF1',
      });
    });

    test('loan lines convert to the shared transaction shape', () {
      final t = CasaTransaction.fromAccountTransaction(
        AccountTransaction.listFromPayload(_payload).first,
      );
      expect(t.title, 'LOAN Principal Repayment');
      expect(t.isCredit, isFalse);
      expect(t.amount.amount, 887);
      expect(t.reference, '000ZTRF2235609RX');
      expect(t.dateTime, DateTime(2026, 10, 5));
    });
  });

  group('Loan Transactions – phone', () {
    testWidgets('OBDX Transactions with the mock layout, no balances', (tester) async {
      final repository = await _pump(tester);

      expect(repository.queries.single, const CasaTransactionQuery());
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Home Loan  |  •••• 0139'), findsOneWidget);
      expect(find.text('Search for amount'), findsOneWidget);
      // OBDX shows Opening / Closing Balance for CASA only.
      expect(find.text('Opening Balance'), findsNothing);
      expect(find.text('October, 2026'), findsOneWidget);
      expect(find.text('September, 2026'), findsOneWidget);
      expect(find.byType(CasaTransactionRow), findsNWidgets(2));
      expect(find.text('Debit'), findsOneWidget);
      expect(find.text('Credit'), findsOneWidget);
    });

    testWidgets('Search for amount = Amount filter (fromAmount = toAmount)', (tester) async {
      final repository = await _pump(tester);
      await tester.enterText(find.byType(TextField), '887');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repository.queries.last.fromAmount, '887');
      expect(repository.queries.last.toAmount, '887');
    });

    testWidgets('filter sheet: OBDX fields, no account dropdown', (tester) async {
      final repository = await _pump(tester);
      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('View Options'), findsOneWidget);
      expect(find.text('Reference Number'), findsOneWidget);
      expect(find.text('Account Number'), findsNothing);

      final amountField = find.descendant(
        of: find.ancestor(of: find.text('Amount'), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      );
      await tester.enterText(amountField.first, '50000');
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.fromAmount, '50000');
      expect(find.widgetWithText(TextField, '50000'), findsOneWidget);
    });

    testWidgets('switching loan keeps the filter', (tester) async {
      final repository = await _pump(tester);
      await tester.enterText(find.byType(TextField), '887');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // The picker reads "Home Loan · xxxxxxxxxxxx0139"; its sheet lists titles.
      await tester.tap(find.text('Home Loan · xxxxxxxxxxxx0139'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Car Loan'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.fromAmount, '887');
    });
  });

  group('Loan Transactions – web', () {
    testWidgets('uses the transactions table', (tester) async {
      await _pump(tester, width: 1280);
      expect(find.byType(CasaTransactionsTable), findsOneWidget);
      expect(find.text('Search for amount'), findsNothing);
    });
  });
}
