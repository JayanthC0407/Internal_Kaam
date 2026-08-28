import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/loan_account_details.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/loan_providers.dart';

/// Identifies a loan for [loanAccountDetailProvider] — the loan id plus its
/// OBDX module (`CON`/`ISL`), both required by the detail sub-resources.
class LoanDetailKey {
  const LoanDetailKey({required this.loanId, this.module});

  final String loanId;
  final String? module;

  @override
  bool operator ==(Object other) =>
      other is LoanDetailKey &&
      other.loanId == loanId &&
      other.module == module;

  @override
  int get hashCode => Object.hash(loanId, module);
}

class LoanDetailState {
  const LoanDetailState({
    this.isLoading = false,
    this.details,
    this.schedule,
    this.outstanding,
    this.disbursements,
    this.errorMessage,
    this.scheduleError,
    this.disbursementsError,
  });

  final bool isLoading;
  final LoanAccountDetails? details;
  final LoanSchedule? schedule;
  final LoanOutstanding? outstanding;
  final List<LoanDisbursement>? disbursements;
  final String? errorMessage;
  final String? scheduleError;
  final String? disbursementsError;

  LoanDetailState copyWith({
    bool? isLoading,
    LoanAccountDetails? details,
    LoanSchedule? schedule,
    LoanOutstanding? outstanding,
    List<LoanDisbursement>? disbursements,
    String? errorMessage,
    String? scheduleError,
    String? disbursementsError,
    bool clearError = false,
  }) {
    return LoanDetailState(
      isLoading: isLoading ?? this.isLoading,
      details: details ?? this.details,
      schedule: schedule ?? this.schedule,
      outstanding: outstanding ?? this.outstanding,
      disbursements: disbursements ?? this.disbursements,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      scheduleError: scheduleError ?? this.scheduleError,
      disbursementsError: disbursementsError ?? this.disbursementsError,
    );
  }
}

class LoanDetailNotifier extends StateNotifier<LoanDetailState> {
  LoanDetailNotifier(this._ref, this._key) : super(const LoanDetailState());

  final Ref _ref;
  final LoanDetailKey _key;
  bool _loadedOnce = false;

  Future<void> ensureLoaded() async {
    if (_loadedOnce || state.isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final repository = _ref.read(loanRepositoryProvider);
    final l10n = await AppLocalizationsHelper.current();

    final detailsResult = await repository.fetchLoanDetails(
      _key.loanId,
      module: _key.module,
    );

    if (detailsResult is! Success<LoanAccountDetails>) {
      _loadedOnce = true;
      state = state.copyWith(
        isLoading: false,
        errorMessage: detailsResult.resolveUserMessage(
          l10n: l10n,
          fallback: l10n.errorLoanDetailsLoadFailed,
        ),
      );
      return;
    }

    _loadedOnce = true;
    state = state.copyWith(isLoading: false, details: detailsResult.data);

    // Schedule and disbursements are fetched best-effort so an overview can
    // still render if either sub-resource is unavailable for this loan type.
    final scheduleFuture =
        repository.fetchLoanSchedule(_key.loanId, module: _key.module);
    final disbursementsFuture =
        repository.fetchLoanDisbursements(_key.loanId, module: _key.module);
    final scheduleResult = await scheduleFuture;
    final disbursementsResult = await disbursementsFuture;

    LoanSchedule? schedule;
    String? scheduleError;
    if (scheduleResult is Success<LoanSchedule>) {
      schedule = scheduleResult.data;
    } else {
      scheduleError = scheduleResult.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.errorLoanScheduleLoadFailed,
      );
    }

    List<LoanDisbursement>? disbursements;
    String? disbursementsError;
    if (disbursementsResult is Success<List<LoanDisbursement>>) {
      disbursements = disbursementsResult.data;
    } else {
      disbursementsError = disbursementsResult.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.errorLoanDisbursementsLoadFailed,
      );
    }

    state = LoanDetailState(
      isLoading: false,
      details: state.details,
      errorMessage: state.errorMessage,
      schedule: schedule,
      scheduleError: scheduleError,
      disbursements: disbursements,
      disbursementsError: disbursementsError,
    );
  }
}

final loanAccountDetailProvider = StateNotifierProvider.family<
    LoanDetailNotifier, LoanDetailState, LoanDetailKey>(
  (ref, key) => LoanDetailNotifier(ref, key),
);
