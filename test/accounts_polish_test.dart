import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/retail/account_transaction.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account_details.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/accounts_repository.dart';
import 'package:ubci_bank/src/infra/repositories/retail/loan_repository.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/dashboard_widgets/retail_dashboard_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/accounts_tab_card.dart';

// ── Fixtures ─────────────────────────────────────────────────────────────

const _savings = CasaAccount(
  id: 'SAV1022',
  displayNumber: 'xxxxxxxxxxxx1022',
  status: 'ACTIVE',
  currencyCode: 'GBP',
  accountType: 'SAVING',
  productName: 'Savings Account',
  availableBalance: MoneyAmount(amount: 12450.75, currency: 'GBP'),
  isDefault: true,
);

const _current = CasaAccount(
  id: 'CUR3381',
  displayNumber: 'xxxxxxxxxxxx3381',
  status: 'ACTIVE',
  currencyCode: 'GBP',
  accountType: 'CURRENT',
  productName: 'Current Account',
  availableBalance: MoneyAmount(amount: 3280.40, currency: 'GBP'),
  holderName: 'Sarah Johnson',
);

const _homeLoan = LoanAccount(
  id: 'LN0139',
  displayNumber: 'xxxxxxxxxxxx0139',
  currencyCode: 'GBP',
  productName: 'Home Loan',
  status: 'ACTIVE',
  holderName: 'Sarah Johnson',
  sanctionedAmount: MoneyAmount(amount: 250000, currency: 'GBP'),
  outstandingAmount: MoneyAmount(amount: 182340.50, currency: 'GBP'),
  module: 'CON',
);

LoanAccountDetails _details({String? status}) => LoanAccountDetails(
      id: 'LN0139',
      displayNumber: 'xxxxxxxxxxxx0139',
      status: status,
      productName: 'Home Loan',
      holderName: 'Sarah Johnson',
      openingDate: DateTime(2021, 4, 15),
      maturityDate: DateTime(2041, 4, 15),
      interestRate: 4.25,
      approvedAmount: const MoneyAmount(amount: 250000, currency: 'GBP'),
      outstandingAmount: const MoneyAmount(amount: 182340.50, currency: 'GBP'),
    );

class _FakeAccounts implements AccountsRepository {
  @override
  Future<ResponseHandler<CasaAccountsSummary>> fetchCasaAccounts() async =>
      ResponseHandler.success(CasaAccountsSummary.fromAccounts(const [_savings, _current]), code: 200);

  @override
  Future<ResponseHandler<CasaAccountsSummary>> fetchCasaAccountsIncludingClosed() => fetchCasaAccounts();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLoans implements LoanRepository {
  _FakeLoans({this.status = 'ACTIVE'});

  final String? status;

  @override
  Future<ResponseHandler<LoanAccountsSummary>> fetchLoans() async => ResponseHandler.success(
        const LoanAccountsSummary(
          loans: [_homeLoan],
          borrowingByCurrency: {'GBP': 250000},
          outstandingByCurrency: {'GBP': 182340.50},
        ),
        code: 200,
      );

  @override
  Future<ResponseHandler<LoanAccountDetails>> fetchLoanDetails(String loanId, {String? module}) async =>
      ResponseHandler.success(_details(status: status), code: 200);

  @override
  Future<ResponseHandler<LoanSchedule>> fetchLoanSchedule(String loanId, {String? module}) async =>
      ResponseHandler.exceptionError();

  @override
  Future<ResponseHandler<List<LoanDisbursement>>> fetchLoanDisbursements(String loanId, {String? module}) async =>
      ResponseHandler.success(const [], code: 200);

  @override
  Future<ResponseHandler<List<AccountTransaction>>> fetchRecentLoanTransactions(
    String loanId, {
    int noOfTransactions = 5,
  }) async =>
      ResponseHandler.success(const [], code: 200);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, Widget home, {_FakeLoans? loans, double height = 1600}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountsRepositoryProvider.overrideWithValue(_FakeAccounts()),
        loanRepositoryProvider.overrideWithValue(loans ?? _FakeLoans()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleConfig.supportedLocales,
        home: Scaffold(body: home),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('shared pieces', () {
    test('account numbers are grouped in fours, masks become dots', () {
      expect(groupAccountNumber('xxxxxxxxxxxx1022'), '•••• •••• •••• 1022');
      expect(groupAccountNumber('9090092909760982'), '9090 0929 0976 0982');
      expect(groupAccountNumber('1234'), '1234');
    });

    test('the list model reads the holder only when OBDX sends partyName', () {
      final withName = CasaAccount.fromJson({
        'id': {'value': 'A1', 'displayValue': 'xxxx1022'},
        'partyName': 'Sarah Johnson',
      });
      final without = CasaAccount.fromJson({
        'id': {'value': 'A1', 'displayValue': 'xxxx1022'},
        'partyId': {'displayValue': '***773'},
      });
      expect(withName.holderName, 'Sarah Johnson');
      expect(without.holderName, isNull);
    });
  });

  group('Accounts list – phone', () {
    testWidgets('grouped numbers, Status chip, holder only when known', (tester) async {
      await _pump(tester, const CasaAccountsListScreen(embedded: true));

      expect(find.text('•••• •••• •••• 1022'), findsOneWidget);
      expect(find.text('Status'), findsNWidgets(2));
      expect(find.text('STATUS'), findsNothing);
      expect(find.text('Search accounts'), findsOneWidget);
      // Only the current account carries partyName — no "—" placeholder.
      expect(find.text('Sarah Johnson'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });
  });

  group('Home – account card', () {
    testWidgets('Savings / Current filter really filters the cards', (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: AccountsTabCard(
            accounts: const [_savings, _current],
            revealedAccountIds: const {},
            onToggleAccountVisibility: (_) {},
            displayName: 'Sarah Johnson',
          ),
        ),
      );
      expect(find.text('All Accounts'), findsOneWidget);
      expect(find.text('View all accounts'), findsOneWidget);

      await tester.tap(find.text('All Accounts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Current Account').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('3381'), findsWidgets);
      expect(find.textContaining('1022'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one account type: a label, not a dropdown', (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: AccountsTabCard(
            accounts: const [_savings],
            revealedAccountIds: const {},
            onToggleAccountVisibility: (_) {},
          ),
        ),
      );
      expect(find.text('Savings Account'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    });
  });

  group('Personalised dashboard widgets on a phone', () {
    testWidgets('Loan Tracker uses the phone design (amount + Outstanding, no View all)', (tester) async {
      await _pump(tester, const SingleChildScrollView(child: RetailLoanSummaryWidget()));
      // The dashboard loads loans before showing this widget; do the same.
      final container = ProviderScope.containerOf(tester.element(find.byType(RetailLoanSummaryWidget)));
      await tester.runAsync(() => container.read(loanAccountsProvider.notifier).ensureLoaded());
      await tester.pumpAndSettle();
      expect(find.text('Outstanding Amount'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('My Spendings uses the stacked phone chart', (tester) async {
      await _pump(tester, const SingleChildScrollView(child: RetailSpendSummaryWidget()));
      // The stacked chart shows the whole amount, without pence.
      expect(find.textContaining('3,182.00'), findsNothing);
      expect(find.textContaining('3,182'), findsOneWidget);
    });
  });

  group('Loans', () {
    testWidgets('list: Total Outstanding card + Total Borrowing tile, nothing invented', (tester) async {
      await _pump(tester, const LoanAccountsListScreen(embedded: true));
      expect(find.text('Total Outstanding'), findsOneWidget);
      expect(find.text('Total Borrowing'), findsOneWidget);
      expect(find.text('1 Loan'), findsOneWidget);
      // The old card showed a hard-coded "Approved" status.
      expect(find.text('Approved'), findsNothing);
      expect(find.text('•••• •••• •••• 0139'), findsOneWidget);
    });

    testWidgets('details: status chip from the bank', (tester) async {
      await _pump(
        tester,
        const LoanAccountDetailsScreen(args: LoanAccountDetailsArgs(loan: _homeLoan)),
        height: 2400,
      );
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('•••• •••• •••• 0139'), findsOneWidget);
    });

    testWidgets('details: no status sent → no invented "Active"', (tester) async {
      await _pump(
        tester,
        const LoanAccountDetailsScreen(args: LoanAccountDetailsArgs(loan: _homeLoan)),
        loans: _FakeLoans(status: null),
        height: 2400,
      );
      expect(find.text('Active'), findsNothing);
    });
  });
}
