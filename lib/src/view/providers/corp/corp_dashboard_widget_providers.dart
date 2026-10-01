import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/models/corp/corp_deposit_overview.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loan_overview.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';

/// Derived state for the Term Deposit and Loan dashboard widgets.
///
/// These are plain [Provider]s over [corpAccountsProvider] rather than
/// notifiers of their own: the deposit and loan lists are already loaded
/// and cached there (and shared with the Accounts tab), so a widget that
/// needs a roll-up should derive it, not fetch the same list again. The
/// derivation re-runs only when the underlying accounts change.
///
/// The lists are lazy — `CorpAccountsNotifier.ensureGroupLoaded` is what
/// triggers the `td/v1/deposit` and `loan/v1/loan` calls, and each widget
/// asks for its own group from a post-frame callback. Until that lands
/// these yield the empty overview, which the widgets render as a spinner.

/// Which account group backs each overview, kept as constants so the
/// widgets and the providers cannot drift apart.
const CorpAccountGroup corpDepositGroup = CorpAccountGroup.deposit;
const CorpAccountGroup corpLoanGroup = CorpAccountGroup.loan;

/// TD Accounts Overview, derived from the loaded deposit list.
final corpTermDepositOverviewProvider = Provider<CorpTermDepositOverview>(
  (ref) => CorpTermDepositOverview.fromAccounts(
    ref.watch(corpAccountsProvider).summary.depositAccounts,
  ),
);

/// Loan Summary / Installments Due / Loan Portfolio, all from the one
/// loaded loan list.
final corpLoanOverviewProvider = Provider<CorpLoanOverview>(
  (ref) => CorpLoanOverview.fromAccounts(
    ref.watch(corpAccountsProvider).summary.loanAccounts,
  ),
);

/// Whether [group]'s list is still being fetched and has produced nothing
/// yet — the condition under which a widget shows its spinner rather than
/// an empty state.
bool corpGroupIsInitialLoading(CorpAccountsState state, CorpAccountGroup group) {
  if (state.summary.accountsIn(group).isNotEmpty) return false;
  return state.isGroupLoading(group) ||
      state.isLoading ||
      !state.isGroupLoaded(group);
}

/// The message a widget shows when [group] produced no rows: the host's
/// error when one was mapped, otherwise the caller's empty-state text.
String? corpGroupMessage(
  CorpAccountsState state,
  CorpAccountGroup group, {
  required String emptyMessage,
}) {
  final error = state.groupError(group) ?? state.errorMessage;
  if (error != null && error.trim().isNotEmpty) return error;
  return emptyMessage;
}
