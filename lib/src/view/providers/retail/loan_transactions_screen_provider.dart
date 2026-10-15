import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/retail/account_transaction.dart';
import 'package:ubci_bank/src/core/models/retail/casa_transaction.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_providers.dart';

class LoanTransactionsScreenState {
  const LoanTransactionsScreenState({
    this.selectedAccountId,
    this.isLoading = false,
    this.transactions = const [],
    this.errorMessage,
    this.query = const CasaTransactionQuery(),
  });

  final String? selectedAccountId;
  final bool isLoading;
  final List<AccountTransaction> transactions;
  final String? errorMessage;

  /// OBDX's Transactions filter (View Options, Transactions, Amount,
  /// Reference Number) — Current Month by default, as in OBDX.
  final CasaTransactionQuery query;

  LoanTransactionsScreenState copyWith({
    String? selectedAccountId,
    bool? isLoading,
    List<AccountTransaction>? transactions,
    String? errorMessage,
    bool clearError = false,
    CasaTransactionQuery? query,
  }) {
    return LoanTransactionsScreenState(
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      isLoading: isLoading ?? this.isLoading,
      transactions: transactions ?? this.transactions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      query: query ?? this.query,
    );
  }
}

/// Drives the full "View All" screen for a loan's transactions — the
/// unlimited-list counterpart to [RecentTransactionsWidgetNotifier].
class LoanTransactionsScreenNotifier
    extends StateNotifier<LoanTransactionsScreenState> {
  LoanTransactionsScreenNotifier(this._ref)
      : super(const LoanTransactionsScreenState());

  final Ref _ref;

  Future<void> selectAccount(String accountId) async {
    if (accountId.isEmpty) return;
    if (state.selectedAccountId == accountId &&
        (state.transactions.isNotEmpty || state.isLoading)) {
      return;
    }

    state = LoanTransactionsScreenState(
      selectedAccountId: accountId,
      isLoading: true,
      query: state.query,
    );
    await _load(accountId);
  }

  /// Apply / Reset in the filter, or the "Search for amount" box.
  Future<void> applyQuery(CasaTransactionQuery query) async {
    final accountId = state.selectedAccountId;
    if (accountId == null || query == state.query) return;
    state = state.copyWith(
      query: query,
      isLoading: true,
      transactions: const [],
      clearError: true,
    );
    await _load(accountId);
  }

  Future<void> refresh() async {
    final accountId = state.selectedAccountId;
    if (accountId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    await _load(accountId);
  }

  Future<void> _load(String accountId) async {
    final result = await _ref
        .read(loanRepositoryProvider)
        .fetchLoanTransactions(accountId, query: state.query);
    final l10n = await AppLocalizationsHelper.current();

    if (state.selectedAccountId != accountId) return;

    if (result is Success<List<AccountTransaction>>) {
      final all = result.data ?? const <AccountTransaction>[];
      if (all.isNotEmpty && all.every((t) => t.looksUnparsed)) {
        state = LoanTransactionsScreenState(
          selectedAccountId: accountId,
          errorMessage: l10n.errorTransactionsLoadFailed,
          query: state.query,
        );
        return;
      }
      state = LoanTransactionsScreenState(
        selectedAccountId: accountId,
        transactions: all,
        query: state.query,
      );
      return;
    }

    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.errorTransactionsLoadFailed,
      ),
    );
  }
}

final loanTransactionsScreenProvider = StateNotifierProvider.autoDispose<
    LoanTransactionsScreenNotifier, LoanTransactionsScreenState>(
  (ref) => LoanTransactionsScreenNotifier(ref),
);
