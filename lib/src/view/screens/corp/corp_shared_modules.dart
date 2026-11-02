import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart';

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
import 'package:ubci_bank/src/view/screens/common/payees/add_bank_account_payee_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payees/add_demand_draft_payee_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payees/add_peer_to_peer_payee_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payees/payee_hub_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payees/payees_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/multiple_transfers_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/network_transfer_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/other_transfers_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/repeat_transfers_screen.dart';
import 'package:ubci_bank/src/view/screens/common/transfer/own_account_transfer_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/loans/corp_loans_hub_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/home/tabs/more_tab_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/home/tabs/transfer_tab_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/term_deposit_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/term_deposits_list_screen.dart';

/// Shows [page] in the dashboard's content area, over what is there now;
/// [page] gets the Back that returns to it.
typedef CorpOpen = void Function(Widget Function(VoidCallback back) page);

/// The modules built for Retail, opened on the Corporate dashboard. Each
/// one is the same screen Retail shows (same OBDX calls — Current &
/// Savings, Loans and Term Deposits read the same `demandDeposit`, `loan`
/// and `deposit` endpoints, which serve a corporate session too).
///
/// Every screen opened from a module — an account's details, Add Biller,
/// a transfer — runs embedded in the dashboard's content area through
/// [CorpOpen], as Retail's do, so the header and the side menu stay on
/// screen all the way through; its Back returns to the screen before.
abstract final class CorpSharedModules {
  /// Accounts → Current & Savings, a row opens the account.
  static Widget currentAndSavings({required CorpOpen open, required VoidCallback onBack}) => CasaAccountsListScreen(
        embedded: true,
        onBack: onBack,
        onAccountSelected: (a) => open((back) => CasaAccountDetailsScreen(accountId: a.id, embedded: true, onBack: back)),
      );

  /// Loan → Loans & Finances, a row opens the loan.
  static Widget loans({required CorpOpen open, required VoidCallback onBack}) => LoanAccountsListScreen(
        embedded: true,
        onBack: onBack,
        onLoanSelected: (l) => open(
          (back) => LoanAccountDetailsScreen(args: LoanAccountDetailsArgs(loan: l), embedded: true, onBack: back),
        ),
      );

  /// Corporate Loans & Finances: the OBCL functions, each opened inside
  /// the dashboard.
  static Widget corporateLoans({required CorpOpen open, required VoidCallback onBack}) =>
      CorpLoansHubScreen(open: open, onBack: onBack);

  /// Term Deposits, a row opens the deposit.
  static Widget termDeposits({required CorpOpen open, required VoidCallback onBack}) => TermDepositsListScreen(
        embedded: true,
        onBack: onBack,
        onDepositSelected: (d) => open(
          (back) => TermDepositDetailsScreen(args: TermDepositDetailsArgs(deposit: d), embedded: true, onBack: back),
        ),
      );

  /// A payee transfer of [mode] (to [payee] when chosen).
  static Widget Function(VoidCallback) _transfer(NetworkTransferMode mode, [TransferPayee? payee]) =>
      (back) => NetworkTransferScreen(
            key: ValueKey((mode, payee?.id)),
            mode: mode,
            initialPayee: payee,
            embedded: true,
            onBack: back,
          );

  /// Transfer → the Payments hub, and every way to pay from it, as Retail
  /// wires them (home_dashboard_screen cases 11-22).
  static Widget transfers({required CorpOpen open}) {
    Widget addPayee(AddPayeeFlow flow, VoidCallback back) => switch (flow) {
          AddPayeeFlow.bankAccount => AddBankAccountPayeeScreen(embedded: true, onBack: back, onCompleted: back),
          AddPayeeFlow.demandDraft => AddDemandDraftPayeeScreen(embedded: true, onBack: back, onCompleted: back),
          AddPayeeFlow.peerToPeer => AddPeerToPeerPayeeScreen(embedded: true, onBack: back, onCompleted: back),
        };
    return TransferTabScreen(
      onTransferTap: (mode, p) => open(_transfer(mode, p)),
      onOtherTransfersTap: () => open(
        (back) => OtherTransfersScreen(
          embedded: true,
          onBack: back,
          onOwnAccountTap: () => open((back) => OwnAccountTransferScreen(embedded: true, onClose: back)),
        ),
      ),
      onMultipleTransfersTap: () => open((back) => MultipleTransfersScreen(embedded: true, onBack: back)),
      onRepeatTransfersTap: () => open(
        (back) => RepeatTransfersScreen(
          embedded: true,
          onBack: back,
          onNewTap: () => open(_transfer(NetworkTransferMode.repeatExistingPayee)),
        ),
      ),
      onPayeeHubTap: () => open(
        (back) => PayeeHubScreen(
          embedded: true,
          onBack: back,
          onPayTap: (p) => open(_transfer(NetworkTransferMode.existingPayee, p)),
          onManagePayeesTap: () => open(
            (back) => PayeesScreen(
              embedded: true,
              onBack: back,
              onPayTap: (p) => open(_transfer(NetworkTransferMode.existingPayee, p)),
              onAddPayee: (flow) => open((back) => addPayee(flow, back)),
            ),
          ),
          onAddAccountPayeeTap: () => open((back) => addPayee(AddPayeeFlow.bankAccount, back)),
          onAddDraftPayeeTap: () => open((back) => addPayee(AddPayeeFlow.demandDraft, back)),
          onAddPeerToPeerPayeeTap: () => open((back) => addPayee(AddPayeeFlow.peerToPeer, back)),
        ),
      ),
    );
  }

  /// Bill → Bill Payments: Billers, Add Biller, Payment History.
  static Widget billPayments({required CorpOpen open, required WidgetRef ref, required VoidCallback onBack}) {
    Widget billers(VoidCallback back) => BillersScreen(embedded: true, onBack: back);
    return BillPaymentsHubScreen(
      onBack: onBack,
      onBillersTap: () => open(billers),
      onHistoryTap: () => open((back) => BillPaymentHistoryScreen(embedded: true, onBack: back)),
      onAddBillerTap: () => open(
        (back) => AddBillerScreen(
          onExit: back,
          // "Back to Billers" on the Done step: the list, with the new one.
          onAdded: (_) {
            ref.invalidate(registeredBillersProvider);
            back();
            open(billers);
          },
        ),
      ),
    );
  }

  /// Credit Card → Credit Cards: the cards and their transactions.
  static Widget creditCards({required CorpOpen open, required VoidCallback onBack}) => CreditCardsHubScreen(
        onBack: onBack,
        onCreditCardsTap: () => open((back) => CreditCardsScreen(embedded: true, onBack: back)),
        onTransactionsTap: () => open((back) => CreditCardTransactionsScreen(embedded: true, onBack: back)),
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
