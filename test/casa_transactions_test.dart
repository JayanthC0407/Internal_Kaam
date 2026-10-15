import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account_detail.dart';
import 'package:ubci_bank/src/core/models/retail/casa_transaction.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/accounts_repository.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_transaction_row.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_transactions_table.dart';

// ── Fixtures ─────────────────────────────────────────────────────────────

const _account = CasaAccount(
  id: 'ACC1',
  displayNumber: 'xxxxxxxxxxxx1022',
  status: 'ACTIVE',
  currencyCode: 'GBP',
);

CasaTransaction _tx(
  String title, {
  required double amount,
  required bool credit,
  required DateTime date,
  String? reference,
}) =>
    CasaTransaction(
      id: '$title-$date',
      title: title,
      amount: MoneyAmount(amount: amount, currency: 'GBP'),
      isCredit: credit,
      dateTime: date,
      reference: reference,
    );

final _october = [
  _tx('Salary Credit', amount: 2000, credit: true, date: DateTime(2026, 10, 5), reference: 'REF100'),
  _tx('Kenyon Inc.', amount: 150.25, credit: false, date: DateTime(2026, 10, 2, 18)),
];
final _september = [
  _tx('Electricity Bill', amount: 80, credit: false, date: DateTime(2026, 9, 28)),
];

// ── Fake repository: answers from fixtures, records every query ──────────

class _FakeAccountsRepository implements AccountsRepository {
  _FakeAccountsRepository(this.transactions);

  final List<CasaTransaction> transactions;
  final queries = <CasaTransactionQuery>[];

  @override
  Future<ResponseHandler<CasaAccountsSummary>> fetchCasaAccounts() async =>
      ResponseHandler.success(
        const CasaAccountsSummary(accounts: [_account], totalsByCurrency: {}),
        code: 200,
      );

  @override
  Future<ResponseHandler<CasaAccountsSummary>> fetchCasaAccountsIncludingClosed() =>
      fetchCasaAccounts();

  @override
  Future<ResponseHandler<CasaAccountDetail>> fetchCasaAccountDetail(String accountId) async =>
      ResponseHandler.exceptionError();

  @override
  Future<ResponseHandler<CasaTransactionsResult>> fetchCasaTransactions(
    String accountId, {
    CasaTransactionQuery query = const CasaTransactionQuery(),
  }) async {
    queries.add(query);
    return ResponseHandler.success(
      CasaTransactionsResult(
        transactions: transactions,
        openingBalance: const MoneyAmount(amount: 1000, currency: 'GBP'),
        closingBalance: const MoneyAmount(amount: 2769.75, currency: 'GBP'),
        currencyCode: 'GBP',
      ),
      code: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeAccountsRepository> _pump(
  WidgetTester tester, {
  required List<CasaTransaction> transactions,
  double width = 390,
  Widget home = const CasaTransactionsScreen(accountId: 'ACC1'),
}) async {
  final repository = _FakeAccountsRepository(transactions);
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accountsRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleConfig.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  group('groupCasaTransactionsByMonth', () {
    test('splits rows into month sections in OBDX order', () {
      final groups = groupCasaTransactionsByMonth([..._october, ..._september]);
      expect(groups.map((g) => g.heading), ['October, 2026', 'September, 2026']);
      expect(groups.first.items.map((t) => t.title), ['Salary Credit', 'Kenyon Inc.']);
    });

    test('rows without a date go last, without a heading', () {
      final undated = CasaTransaction(
        id: 'x',
        title: 'No date',
        amount: const MoneyAmount(amount: 1, currency: 'GBP'),
        isCredit: true,
      );
      final groups = groupCasaTransactionsByMonth([undated, ..._september]);
      expect(groups.map((g) => g.heading), ['September, 2026', null]);
    });
  });

  group('Transactions – phone', () {
    testWidgets('shows the mock layout with OBDX data', (tester) async {
      await _pump(tester, transactions: [..._october, ..._september]);

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Search for amount'), findsOneWidget);
      expect(find.text('Opening Balance'), findsOneWidget);
      expect(find.text('Closing Balance'), findsOneWidget);
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('October, 2026'), findsOneWidget);
      expect(find.text('September, 2026'), findsOneWidget);
      expect(find.text('Salary Credit'), findsOneWidget);
      // Value dates (midnight) show no time; real times do.
      expect(find.text('•••• 1022  |  GBP'), findsOneWidget);
      expect(find.text('05 Oct 2026'), findsOneWidget);
      expect(find.text('Ref: REF100'), findsOneWidget);
      expect(find.text('02 Oct 2026  •  6:00 PM'), findsOneWidget);
      // OBDX Transaction Type under the amount.
      expect(find.text('Credit'), findsOneWidget);
      expect(find.text('Debit'), findsNWidgets(2));
      expect(find.byType(CasaTransactionsTable), findsNothing);
    });

    testWidgets('Search for amount = OBDX Amount filter (fromAmount = toAmount)', (tester) async {
      final repository = await _pump(tester, transactions: _october);
      expect(repository.queries.last.fromAmount, isNull);

      await tester.enterText(find.byType(TextField), '150.25');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(repository.queries.last.fromAmount, '150.25');
      expect(repository.queries.last.toAmount, '150.25');
      expect(repository.queries.last.toQueryParameters()['fromAmount'], '150.25');

      // The clear button drops the filter and reloads.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(repository.queries.last.fromAmount, isNull);
      expect(repository.queries.last.toAmount, isNull);
    });

    testWidgets('filter sheet has OBDX\'s single Amount field', (tester) async {
      final repository = await _pump(tester, transactions: _october);

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('From Amount'), findsNothing);
      expect(find.text('To Amount'), findsNothing);

      final amountField = find.descendant(
        of: find.ancestor(of: find.text('Amount'), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      );
      await tester.enterText(amountField.first, '80');
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(repository.queries.last.fromAmount, '80');
      expect(repository.queries.last.toAmount, '80');
      // The header search box shows the same amount.
      expect(find.widgetWithText(TextField, '80'), findsOneWidget);
    });

    testWidgets('loads 10 more rows at a time, like OBDX loadMoreOnScroll', (tester) async {
      final many = [
        for (var i = 1; i <= 25; i++)
          _tx('Payment $i', amount: i.toDouble(), credit: i.isEven, date: DateTime(2026, 10, 1)),
      ];
      await _pump(tester, transactions: many);

      final rows = find.byType(CasaTransactionRow, skipOffstage: false);
      expect(rows, findsNWidgets(10));
      expect(find.text('Load More', skipOffstage: false), findsOneWidget);

      // Tapping "Load More" adds the next 10.
      // (Called directly: scrolling to the button would itself load more.)
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Load More', skipOffstage: false))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(rows, findsNWidgets(20));

      // Scrolling near the end loads the rest on its own.
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(rows, findsNWidgets(25));
      expect(find.text('Load More', skipOffstage: false), findsNothing);
    });

    testWidgets('empty period shows OBDX message', (tester) async {
      await _pump(tester, transactions: const []);
      expect(find.text('No Activity found for the specified period.'), findsOneWidget);
    });
  });

  group('Account Details – Recent Transactions', () {
    testWidgets('phone uses the same month-grouped rows', (tester) async {
      await _pump(
        tester,
        transactions: [..._october, ..._september],
        home: const CasaAccountDetailsScreen(accountId: 'ACC1'),
      );
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('October, 2026'), findsOneWidget);
      expect(find.byType(CasaTransactionRow), findsNWidgets(3));
      expect(find.text('Credit'), findsOneWidget);
    });

    testWidgets('web keeps the table', (tester) async {
      await _pump(
        tester,
        transactions: _october,
        width: 1280,
        home: const CasaAccountDetailsScreen(accountId: 'ACC1'),
      );
      expect(find.byType(CasaTransactionsTable), findsOneWidget);
      expect(find.byType(CasaTransactionRow), findsNothing);
    });
  });

  group('Transactions – web', () {
    testWidgets('keeps the wide table layout', (tester) async {
      await _pump(tester, transactions: _october, width: 1280);
      expect(find.byType(CasaTransactionsTable), findsOneWidget);
      expect(find.text('Search for amount'), findsNothing);
    });
  });
}
