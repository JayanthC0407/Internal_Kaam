import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/loan_account_details.dart';
import 'package:ubci_bank/src/core/models/loan_repayment.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/loan_detail_providers.dart';
import 'package:ubci_bank/src/view/providers/loan_providers.dart';

/// OBDX task code for the loan repayment flow — used both to filter
/// eligible settlement (CASA) accounts and, in the wider OBDX web app, to
/// scope the loan list itself.
const String kLoanRepaymentTaskCode = 'LN_F_LRP';

/// CASA accounts eligible to settle a loan repayment
/// (`GET /digx-common/dda/v1/demandDeposit?taskCode=LN_F_LRP`).
final loanRepaymentSettlementAccountsProvider =
    FutureProvider.autoDispose<List<CasaAccount>>((ref) async {
  final l10n = await AppLocalizationsHelper.current();
  final result = await ref
      .read(accountsRepositoryProvider)
      .fetchSettlementAccounts(taskCode: kLoanRepaymentTaskCode);

  if (result is Success<List<CasaAccount>>) {
    return result.data ?? const [];
  }
  throw result.resolveUserMessage(
    l10n: l10n,
    fallback: l10n.errorAccountsLoadFailed,
  );
});

/// Outstanding balance for a specific loan, fetched with
/// `repaymentType=P` as seen in the repayment screen capture — this is
/// the amount the repayment form defaults to and validates against.
final loanRepaymentOutstandingProvider = FutureProvider.autoDispose
    .family<LoanOutstanding, LoanDetailKey>((ref, key) async {
  final l10n = await AppLocalizationsHelper.current();
  final result = await ref.read(loanRepositoryProvider).fetchLoanOutstanding(
        key.loanId,
        module: key.module,
        repaymentType: 'P',
      );

  if (result is Success<LoanOutstanding>) {
    return result.data ?? const LoanOutstanding();
  }
  throw result.resolveUserMessage(
    l10n: l10n,
    fallback: l10n.errorLoanOutstandingLoadFailed,
  );
});

class LoanRepaymentSubmissionState {
  const LoanRepaymentSubmissionState({
    this.isSubmitting = false,
    this.result,
    this.errorMessage,
    this.otpChallenge,
    this.otpError,
  });

  final bool isSubmitting;
  final LoanRepaymentResult? result;
  final String? errorMessage;

  /// Set while OBDX is waiting for an OTP (host has step-up auth enabled
  /// for this task). Null on hosts where OTP is disabled — they go
  /// straight from submitting to [result].
  final LoanRepaymentChallenge? otpChallenge;

  /// Inline error shown on the OTP sheet (e.g. wrong code) — kept
  /// separate from [errorMessage] so it doesn't also pop a snackbar.
  final String? otpError;
}

class LoanRepaymentSubmissionNotifier
    extends StateNotifier<LoanRepaymentSubmissionState> {
  LoanRepaymentSubmissionNotifier(this._ref)
      : super(const LoanRepaymentSubmissionState());

  final Ref _ref;
  String? _loanId;
  LoanRepaymentRequest? _request;

  Future<void> submit({
    required String loanId,
    required LoanRepaymentRequest request,
  }) async {
    _loanId = loanId;
    _request = request;
    state = const LoanRepaymentSubmissionState(isSubmitting: true);
    await _attempt();
  }

  /// Retries the same repayment request with the OTP the user entered for
  /// the current [LoanRepaymentSubmissionState.otpChallenge].
  Future<void> verifyOtp(String otp) async {
    final challenge = state.otpChallenge;
    if (challenge == null) return;
    state = LoanRepaymentSubmissionState(
      isSubmitting: true,
      otpChallenge: challenge,
    );
    await _attempt(otp: otp, challenge: challenge);
  }

  Future<void> _attempt({String? otp, LoanRepaymentChallenge? challenge}) async {
    final loanId = _loanId;
    final request = _request;
    if (loanId == null || request == null) return;

    final l10n = await AppLocalizationsHelper.current();
    final result = await _ref.read(loanRepositoryProvider).submitRepayment(
          loanId: loanId,
          request: request,
          otp: otp,
          challenge: challenge,
        );

    if (result is Success<LoanRepaymentOutcome>) {
      final outcome = result.data;
      if (outcome is LoanRepaymentCompleted) {
        state = LoanRepaymentSubmissionState(result: outcome.result);
        return;
      }
      if (outcome is LoanRepaymentAwaitingOtp) {
        // A second 417 while verifying means the OTP we sent was wrong —
        // OBDX still returns a fresh challenge with attemptsLeft
        // decremented, so surface that with an inline error.
        state = LoanRepaymentSubmissionState(
          otpChallenge: outcome.challenge,
          otpError: otp != null ? l10n.loanRepaymentOtpIncorrect : null,
        );
        return;
      }
      state = LoanRepaymentSubmissionState(
        errorMessage: l10n.errorLoanRepaymentFailed,
      );
      return;
    }

    // A genuine failure (network/business error, not a wrong OTP) while
    // verifying — keep the challenge alive so the sheet stays open with
    // an inline error instead of losing the user's place in the flow.
    if (otp != null && challenge != null) {
      state = LoanRepaymentSubmissionState(
        otpChallenge: challenge,
        otpError: result.resolveUserMessage(
          l10n: l10n,
          fallback: l10n.errorLoanRepaymentFailed,
        ),
      );
      return;
    }

    state = LoanRepaymentSubmissionState(
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.errorLoanRepaymentFailed,
      ),
    );
  }

  void reset() {
    _loanId = null;
    _request = null;
    state = const LoanRepaymentSubmissionState();
  }
}

final loanRepaymentSubmissionProvider = StateNotifierProvider.autoDispose<
    LoanRepaymentSubmissionNotifier, LoanRepaymentSubmissionState>(
  (ref) => LoanRepaymentSubmissionNotifier(ref),
);
