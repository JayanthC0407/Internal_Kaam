import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/account_category.dart';
import 'package:ubci_bank/src/core/models/account_transaction.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/casa_transaction.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/loan_providers.dart';

/// A minimal, category-agnostic account reference for the widget's
/// "Account Number" dropdown — adapted from whichever domain model
/// (`CasaAccount`, `LoanAccount`) the selected [AccountCategory] uses.
class SelectableAccount {
  const SelectableAccount({
    required this.id,
    required this.title,
    required this.subtitle,
    this.balance,
  });

  final String id;
  final String title;

  /// Masked account/loan number shown under the title.
  final String subtitle;

  final MoneyAmount? balance;
}

class RecentTransactionsWidgetState {
  const RecentTransactionsWidgetState({
    this.category = AccountCategory.currentAndSavings,
    this.isLoadingAccounts = false,
    this.accounts = const [],
    this.accountsErrorMessage,
    this.selectedAccountId,
    this.isLoadingTransactions = false,
    this.casaTransactions = const [],
    this.loanTransactions = const [],
    this.transactionsErrorMessage,
  });

  final AccountCategory category;
  final bool isLoadingAccounts;
  final List<SelectableAccount> accounts;
  final String? accountsErrorMessage;
  final String? selectedAccountId;
  final bool isLoadingTransactions;

  /// Populated when [category] is `currentAndSavings` — kept as
  /// [CasaTransaction] (rather than converted) so the widget can reuse
  /// [CasaTransactionTile], matching the look of the full CASA statement
  /// screen.
  final List<CasaTransaction> casaTransactions;

  /// Populated when [category] is `loans`.
  final List<AccountTransaction> loanTransactions;

  final String? transactionsErrorMessage;

  bool get isLoadingTransactionsForList => isLoadingTransactions;

  bool get transactionsAreEmpty => category == AccountCategory.currentAndSavings
      ? casaTransactions.isEmpty
      : loanTransactions.isEmpty;

  RecentTransactionsWidgetState copyWith({
    AccountCategory? category,
    bool? isLoadingAccounts,
    List<SelectableAccount>? accounts,
    String? accountsErrorMessage,
    String? selectedAccountId,
    bool? isLoadingTransactions,
    List<CasaTransaction>? casaTransactions,
    List<AccountTransaction>? loanTransactions,
    String? transactionsErrorMessage,
    bool clearAccountsError = false,
    bool clearTransactionsError = false,
  }) {
    return RecentTransactionsWidgetState(
      category: category ?? this.category,
      isLoadingAccounts: isLoadingAccounts ?? this.isLoadingAccounts,
      accounts: accounts ?? this.accounts,
      accountsErrorMessage: clearAccountsError
          ? null
          : (accountsErrorMessage ?? this.accountsErrorMessage),
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      isLoadingTransactions:
          isLoadingTransactions ?? this.isLoadingTransactions,
      casaTransactions: casaTransactions ?? this.casaTransactions,
      loanTransactions: loanTransactions ?? this.loanTransactions,
      transactionsErrorMessage: clearTransactionsError
          ? null
          : (transactionsErrorMessage ?? this.transactionsErrorMessage),
    );
  }
}

/// Drives the dashboard's "Recent Transactions" widget across the
/// currently-supported account types (CASA, Loans — see
/// [AccountCategory.isSupported]). Reuses the app's existing
/// [casaAccountsProvider] / [loanAccountsProvider] caches rather than
/// fetching its own account lists, so switching categories here doesn't
/// duplicate work the dashboard has already done.
class RecentTransactionsWidgetNotifier
    extends StateNotifier<RecentTransactionsWidgetState> {
  RecentTransactionsWidgetNotifier(this._ref)
      : super(const RecentTransactionsWidgetState());

  final Ref _ref;
  bool _hasLoadedOnce = false;

  Future<void> ensureLoaded() async {
    if (_hasLoadedOnce) return;
    _hasLoadedOnce = true;
    await selectCategory(AccountCategory.currentAndSavings);
  }

  Future<void> selectCategory(AccountCategory category) async {
    state = RecentTransactionsWidgetState(
      category: category,
      isLoadingAccounts: true,
    );

    // Term/Recurring Deposits and Credit Cards: no working integration
    // yet — shown as a placeholder rather than guessing at unconfirmed
    // fields/endpoints.
    if (!category.isSupported) {
      state = state.copyWith(isLoadingAccounts: false);
      return;
    }

    List<SelectableAccount> accounts = const [];
    String? error;

    switch (category) {
      case AccountCategory.currentAndSavings:
        await _ref.read(casaAccountsProvider.notifier).ensureLoaded();
        final casaState = _ref.read(casaAccountsProvider);
        accounts = (casaState.summary?.accounts ?? const [])
            .map(
              (a) => SelectableAccount(
                id: a.id,
                title: a.title,
                subtitle: a.maskedNumber,
                balance: a.displayBalance,
              ),
            )
            .toList();
        error = casaState.summary == null ? casaState.errorMessage : null;
        break;

      case AccountCategory.loans:
        await _ref.read(loanAccountsProvider.notifier).ensureLoaded();
        final loanState = _ref.read(loanAccountsProvider);
        accounts = (loanState.summary?.loans ?? const [])
            .map(
              (a) => SelectableAccount(
                id: a.id,
                title: a.title,
                subtitle: a.displayNumber,
                balance: a.outstandingAmount,
              ),
            )
            .toList();
        error = loanState.summary == null ? loanState.errorMessage : null;
        break;

      case AccountCategory.termDeposits:
      case AccountCategory.recurringDeposits:
      case AccountCategory.creditCards:
        break; // unreachable — isSupported already returned above
    }

    // The user may have switched categories again while this was in
    // flight — don't clobber whatever they've since selected.
    if (state.category != category) return;

    state = state.copyWith(
      isLoadingAccounts: false,
      accounts: accounts,
      accountsErrorMessage: error,
      clearAccountsError: error == null,
    );

    if (accounts.isNotEmpty) {
      await selectAccount(accounts.first.id);
    }
  }

  /// Forces a re-fetch of the current category's account list (used by
  /// the widget's error-state retry button), rather than the
  /// once-per-session [ensureLoaded] caches.
  Future<void> retryAccounts() async {
    final category = state.category;
    switch (category) {
      case AccountCategory.currentAndSavings:
        await _ref.read(casaAccountsProvider.notifier).refresh();
        break;
      case AccountCategory.loans:
        await _ref.read(loanAccountsProvider.notifier).refresh();
        break;
      case AccountCategory.termDeposits:
      case AccountCategory.recurringDeposits:
      case AccountCategory.creditCards:
        return;
    }
    await selectCategory(category);
  }

  Future<void> selectAccount(String accountId) async {
    final category = state.category;
    state = state.copyWith(
      selectedAccountId: accountId,
      isLoadingTransactions: true,
      clearTransactionsError: true,
    );

    final l10n = await AppLocalizationsHelper.current();

    if (category == AccountCategory.currentAndSavings) {
      final result = await _ref
          .read(accountsRepositoryProvider)
          .fetchCasaTransactions(accountId);

      if (state.category != category || state.selectedAccountId != accountId) {
        return;
      }

      if (result is Success<CasaTransactionsResult>) {
        final all = result.data?.transactions ?? const <CasaTransaction>[];
        state = state.copyWith(
          isLoadingTransactions: false,
          casaTransactions: all.take(5).toList(),
          clearTransactionsError: true,
        );
        return;
      }

      if (SessionExpiryCoordinator.instance.isHandling) {
        state = state.copyWith(isLoadingTransactions: false, clearTransactionsError: true);
        return;
      }

      state = state.copyWith(
        isLoadingTransactions: false,
        transactionsErrorMessage: result.resolveUserMessage(
          l10n: l10n,
          fallback: l10n.errorTransactionsLoadFailed,
        ),
      );
      return;
    }

    if (category == AccountCategory.loans) {
      final result = await _ref
          .read(loanRepositoryProvider)
          .fetchRecentLoanTransactions(accountId);

      if (state.category != category || state.selectedAccountId != accountId) {
        return;
      }

      if (result is Success<List<AccountTransaction>>) {
        final all = result.data ?? const <AccountTransaction>[];
        // If the fetch returned rows but parsing produced nothing usable
        // out of every one of them, this is a field-mapping mismatch
        // (see AccountTransaction.looksUnparsed), not genuinely zero
        // transactions — surface it as an error rather than fabricated
        // $0.00 rows.
        if (all.isNotEmpty && all.every((t) => t.looksUnparsed)) {
          state = state.copyWith(
            isLoadingTransactions: false,
            loanTransactions: const [],
            transactionsErrorMessage: l10n.errorTransactionsLoadFailed,
          );
          return;
        }
        state = state.copyWith(
          isLoadingTransactions: false,
          loanTransactions: all,
          clearTransactionsError: true,
        );
        return;
      }

      if (SessionExpiryCoordinator.instance.isHandling) {
        state = state.copyWith(isLoadingTransactions: false, clearTransactionsError: true);
        return;
      }

      state = state.copyWith(
        isLoadingTransactions: false,
        transactionsErrorMessage: result.resolveUserMessage(
          l10n: l10n,
          fallback: l10n.errorTransactionsLoadFailed,
        ),
      );
      return;
    }

    // Unreachable — Term/Recurring Deposits and Credit Cards never
    // populate `accounts`, so `selectAccount` is never called for them.
  }

  Future<void> refresh() async {
    final accountId = state.selectedAccountId;
    if (accountId == null) {
      await retryAccounts();
      return;
    }
    await selectAccount(accountId);
  }
}

final recentTransactionsWidgetProvider = StateNotifierProvider.autoDispose<
    RecentTransactionsWidgetNotifier, RecentTransactionsWidgetState>(
  (ref) => RecentTransactionsWidgetNotifier(ref),
);
