import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/loan_repository.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/network_providers.dart';

final loanRepositoryProvider = Provider(
  (ref) => LoanRepository(
    loanApi: ref.watch(obdxLoanApiProvider),
  ),
);

class LoanAccountsState {
  const LoanAccountsState({
    this.isLoading = false,
    this.summary,
    this.errorMessage,
  });

  final bool isLoading;
  final LoanAccountsSummary? summary;
  final String? errorMessage;

  LoanAccountsState copyWith({
    bool? isLoading,
    LoanAccountsSummary? summary,
    String? errorMessage,
    bool clearError = false,
    bool clearSummary = false,
  }) {
    return LoanAccountsState(
      isLoading: isLoading ?? this.isLoading,
      summary: clearSummary ? null : (summary ?? this.summary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LoanAccountsNotifier extends StateNotifier<LoanAccountsState> {
  LoanAccountsNotifier(this._ref) : super(const LoanAccountsState());

  final Ref _ref;
  bool _loadedOnce = false;

  Future<void> ensureLoaded() async {
    if (_loadedOnce || state.isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _ref.read(loanRepositoryProvider).fetchLoans();
    final l10n = await AppLocalizationsHelper.current();

    if (result is Success<LoanAccountsSummary>) {
      _loadedOnce = true;
      state = LoanAccountsState(
        isLoading: false,
        summary: result.data ??
            const LoanAccountsSummary(
              loans: [],
              borrowingByCurrency: {},
              outstandingByCurrency: {},
            ),
      );
      return;
    }

    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    _loadedOnce = true;
    state = state.copyWith(
      isLoading: false,
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.errorLoansLoadFailed,
      ),
    );
  }
}

final loanAccountsProvider =
    StateNotifierProvider<LoanAccountsNotifier, LoanAccountsState>(
  (ref) => LoanAccountsNotifier(ref),
);
