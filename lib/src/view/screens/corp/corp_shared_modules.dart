import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/add_biller_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/bill_payment_history_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/bill_payments_hub_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/billers_screen.dart';
import 'package:ubci_bank/src/view/screens/common/calculators/calculator_screens.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/credit_card_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/credit_cards_hub_screen.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/credit_cards_screen.dart';
import 'package:ubci_bank/src/view/screens/common/mailbox/mailbox_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/home/tabs/more_tab_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/home/tabs/transfer_tab_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/term_deposit_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/term_deposits_list_screen.dart';

/// The modules built for Retail, opened on the Corporate dashboard. Each
/// one is the same screen Retail shows (same OBDX calls — Current &
/// Savings, Loans and Term Deposits read the same `demandDeposit`, `loan`
/// and `deposit` endpoints, which serve a corporate session too).
///
/// Corporate has no section indexes, so a module's first page is the
/// destination itself and what opens from it is pushed: on the desktop
/// layout that lands in the content area beside the side menu
/// (`SidebarContentNavigator`), on a phone it is its own page; either way
/// the screen's own Back pops it.
abstract final class CorpSharedModules {
  static void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  /// Accounts → Current & Savings, a row opens the account.
  static Widget currentAndSavings(BuildContext context, {required VoidCallback onBack}) => CasaAccountsListScreen(
        embedded: true,
        onBack: onBack,
        onAccountSelected: (a) => _push(context, CasaAccountDetailsScreen(accountId: a.id)),
      );

  /// Loan → Loans & Finances, a row opens the loan.
  static Widget loans(BuildContext context, {required VoidCallback onBack}) => LoanAccountsListScreen(
        embedded: true,
        onBack: onBack,
        onLoanSelected: (l) => _push(context, LoanAccountDetailsScreen(args: LoanAccountDetailsArgs(loan: l))),
      );

  /// Term Deposits, a row opens the deposit.
  static Widget termDeposits(BuildContext context, {required VoidCallback onBack}) => TermDepositsListScreen(
        embedded: true,
        onBack: onBack,
        onDepositSelected: (d) => _push(context, TermDepositDetailsScreen(args: TermDepositDetailsArgs(deposit: d))),
      );

  /// Transfer → the Payments hub; every way to pay opens its own screen.
  static Widget transfers() => const TransferTabScreen();

  /// Bill → Bill Payments: Billers, Add Biller, Payment History.
  static Widget billPayments(BuildContext context, WidgetRef ref) => BillPaymentsHubScreen(
        onBillersTap: () => _push(context, const BillersScreen()),
        onHistoryTap: () => _push(context, const BillPaymentHistoryScreen()),
        onAddBillerTap: () => _push(
          context,
          Builder(
            builder: (page) => AddBillerScreen(
              onExit: () => Navigator.of(page).pop(),
              // "Back to Billers" on the Done step: the list, with the new one.
              onAdded: (_) {
                ref.invalidate(registeredBillersProvider);
                Navigator.of(page).pushReplacement(MaterialPageRoute<void>(builder: (_) => const BillersScreen()));
              },
            ),
          ),
        ),
      );

  /// Credit Card → Credit Cards: the cards and their transactions.
  static Widget creditCards(BuildContext context) => CreditCardsHubScreen(
        onCreditCardsTap: () => _push(context, const CreditCardsScreen()),
        onTransactionsTap: () => _push(context, const CreditCardTransactionsScreen()),
      );

  /// Mailbox (Mails, Alerts, Notifications); also the bell.
  static Widget mailbox({required String userName, required VoidCallback onBack}) =>
      MailboxScreen(userName: userName, embedded: true, onBack: onBack);

  /// More — Retail's services hub: the profile card (opens My
  /// Preferences), Networth / Rewards, Services (Mailbox, Service Requests,
  /// Calculators), Discover, Help, Log out. Corporate has no Rewards tab,
  /// so that tile says Coming soon.
  static Widget more({
    required String displayName,
    required VoidCallback onProfileTap,
    required VoidCallback onMailboxTap,
    required VoidCallback onServiceRequestsTap,
    required VoidCallback onCalculatorsTap,
  }) =>
      MoreTabScreen(
        displayName: displayName,
        onProfileTap: onProfileTap,
        onMailboxTap: onMailboxTap,
        onServiceRequestsTap: onServiceRequestsTap,
        onCalculatorsTap: onCalculatorsTap,
      );

  /// Financial Calculator (Term Deposit, Loan Installment, Loan
  /// Eligibility, Forex).
  static Widget calculators({required VoidCallback onBack}) => FinancialCalculatorScreen(onBack: onBack);
}
