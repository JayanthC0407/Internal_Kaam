import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:demo_bank/src/core/models/common/cards/credit_card_models.dart';
import 'package:demo_bank/src/core/models/retail/account_category.dart';
import 'package:demo_bank/src/core/models/retail/casa_account.dart';
import 'package:demo_bank/src/core/models/retail/casa_transaction.dart';
import 'package:demo_bank/src/core/models/retail/loan_account.dart';
import 'package:demo_bank/src/view/providers/common/credit_card_providers.dart';
import 'package:demo_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:demo_bank/src/view/providers/retail/loan_providers.dart';
import 'package:demo_bank/src/view/providers/retail/recent_transactions_widget_providers.dart';

/// Sample data for the Studio preview: the data providers behind Retail's
/// Home widgets, replaced so those widgets draw without OBDX. Invented
/// values, clearly not a customer's (CONTRACT-OBDX rule 0.1).
class RetailPreviewSamples {
  const RetailPreviewSamples._();

  static const _ccy = 'INR';
  static MoneyAmount _m(double v) => MoneyAmount(amount: v, currency: _ccy);

  static final accounts = <CasaAccount>[
    CasaAccount(
      id: 'SAMPLE-1',
      displayNumber: '0000 0000 1234',
      status: 'ACTIVE',
      currencyCode: _ccy,
      accountType: 'SAVING',
      nickname: 'Sample Savings',
      availableBalance: _m(125000),
      isDefault: true,
    ),
    CasaAccount(
      id: 'SAMPLE-2',
      displayNumber: '0000 0000 5678',
      status: 'ACTIVE',
      currencyCode: _ccy,
      accountType: 'CURRENT',
      nickname: 'Sample Current',
      availableBalance: _m(48250.5),
    ),
  ];

  static final loans = <LoanAccount>[
    LoanAccount(
      id: 'SAMPLE-L1',
      displayNumber: '0000 0000 9012',
      currencyCode: _ccy,
      productName: 'Sample Home Loan',
      status: 'ACTIVE',
      sanctionedAmount: _m(2500000),
      outstandingAmount: _m(1640000),
    ),
  ];

  static final cards = <CreditCard>[
    CreditCard(
      id: 'SAMPLE-C1',
      displayNumber: '0000 00XX XXXX 4417',
      ownerName: 'SAMPLE CUSTOMER',
      status: CreditCardStatus.active,
      availableCredit: _m(180000),
      creditLimit: _m(200000),
      currentOutstanding: _m(20000),
    ),
  ];

  static final transactions = <CasaTransaction>[
    CasaTransaction(id: 'T1', title: 'Salary credit', amount: _m(85000), isCredit: true, transactionDate: DateTime(2026, 11, 1)),
    CasaTransaction(id: 'T2', title: 'Grocery store', amount: _m(2340), isCredit: false, transactionDate: DateTime(2026, 11, 3)),
    CasaTransaction(id: 'T3', title: 'Electricity bill', amount: _m(1875), isCredit: false, transactionDate: DateTime(2026, 11, 5)),
  ];

  /// Overrides for the preview's ProviderScope.
  static List<Override> get overrides => [
        casaAccountsProvider.overrideWith((ref) => _SampleCasa(ref)),
        loanAccountsProvider.overrideWith((ref) => _SampleLoans(ref)),
        recentTransactionsWidgetProvider.overrideWith((ref) => _SampleRecent(ref)),
        creditCardsProvider.overrideWith((ref) async => cards),
      ];
}

class _SampleCasa extends CasaAccountsNotifier {
  _SampleCasa(super.ref) {
    state = CasaAccountsState(
      summary: CasaAccountsSummary(
        accounts: RetailPreviewSamples.accounts,
        totalsByCurrency: {'INR': 173250.5},
      ),
    );
  }

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> refreshIncludingClosed() async {}
}

class _SampleLoans extends LoanAccountsNotifier {
  _SampleLoans(super.ref) {
    state = LoanAccountsState(
      summary: LoanAccountsSummary(
        loans: RetailPreviewSamples.loans,
        borrowingByCurrency: {'INR': 2500000},
        outstandingByCurrency: {'INR': 1640000},
      ),
    );
  }

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> refresh() async {}
}

class _SampleRecent extends RecentTransactionsWidgetNotifier {
  _SampleRecent(super.ref) {
    state = RecentTransactionsWidgetState(
      category: AccountCategory.currentAndSavings,
      accounts: [
        for (final a in RetailPreviewSamples.accounts)
          SelectableAccount(id: a.id, title: a.title, subtitle: a.maskedNumber, balance: a.displayBalance),
      ],
      selectedAccountId: RetailPreviewSamples.accounts.first.id,
      casaTransactions: RetailPreviewSamples.transactions,
    );
  }

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> selectCategory(AccountCategory category) async {}

  @override
  Future<void> selectAccount(String accountId) async {}

  @override
  Future<void> retryAccounts() async {}

  @override
  Future<void> refresh() async {}
}
