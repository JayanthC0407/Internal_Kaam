import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/retail/account_transaction.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit_actions.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/retail/accounts_repository.dart';
import 'package:ubci_bank/src/infra/repositories/retail/term_deposit_repository.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';

final termDepositRepositoryProvider = Provider(
  (ref) => TermDepositRepository(api: ref.watch(obdxTermDepositApiProvider)),
);

// ── The list ─────────────────────────────────────────────────────────────

class TermDepositsState {
  const TermDepositsState({
    this.isLoading = false,
    this.summary,
    this.errorMessage,
  });

  final bool isLoading;
  final TermDepositsSummary? summary;
  final String? errorMessage;
}

/// Active and closed deposits (`GET .../deposit?...&status=ACTIVE&status=
/// CLOSED`), loaded once and shared by the list, the home widgets and the
/// action pickers.
class TermDepositsNotifier extends StateNotifier<TermDepositsState> {
  TermDepositsNotifier(this._ref) : super(const TermDepositsState());

  final Ref _ref;
  bool _loadedOnce = false;
  Future<void>? _pending;

  Future<void> ensureLoaded() {
    if (_loadedOnce) return Future.value();
    return _pending ??= refresh().whenComplete(() => _pending = null);
  }

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    state = TermDepositsState(isLoading: true, summary: state.summary);
    final result =
        await _ref.read(termDepositRepositoryProvider).fetchDeposits();
    final l10n = await AppLocalizationsHelper.current();
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;

    _loadedOnce = true;
    if (result is Success<TermDepositsSummary>) {
      state = TermDepositsState(
        summary: result.data ?? TermDepositsSummary.fromDeposits(const []),
      );
      return;
    }
    if (SessionExpiryCoordinator.instance.isHandling) {
      state = TermDepositsState(summary: state.summary);
      return;
    }
    state = TermDepositsState(
      summary: state.summary,
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.tdLoadFailed,
      ),
    );
  }
}

final termDepositsProvider =
    StateNotifierProvider<TermDepositsNotifier, TermDepositsState>(
  (ref) => TermDepositsNotifier(ref),
);

// ── One deposit ──────────────────────────────────────────────────────────

class TdDetailState {
  const TdDetailState({
    this.isLoading = false,
    this.deposit,
    this.payouts,
    this.errorMessage,
    this.payoutsError,
  });

  final bool isLoading;
  final TermDeposit? deposit;
  final List<TdPayoutInstruction>? payouts;
  final String? errorMessage;
  final String? payoutsError;
}

/// The deposit's details and its payout instructions, fetched together.
/// The payout instructions are best-effort: the details still show if
/// that call fails.
class TdDetailNotifier extends StateNotifier<TdDetailState> {
  TdDetailNotifier(this._ref, this._id) : super(const TdDetailState());

  final Ref _ref;
  final String _id;
  bool _loadedOnce = false;

  Future<void> ensureLoaded() async {
    if (_loadedOnce || state.isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    state = TdDetailState(
      isLoading: true,
      deposit: state.deposit,
      payouts: state.payouts,
    );
    final repository = _ref.read(termDepositRepositoryProvider);
    final l10n = await AppLocalizationsHelper.current();
    final results = await Future.wait([
      repository.fetchDeposit(_id),
      repository.fetchPayoutInstructions(_id),
    ]);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    _loadedOnce = true;

    final detail = results[0];
    final payouts = results[1];
    if (detail is! Success<TermDeposit> || detail.data == null) {
      state = TdDetailState(
        deposit: state.deposit,
        payouts: state.payouts,
        errorMessage: detail.resolveUserMessage(
          l10n: l10n,
          fallback: l10n.tdDetailsLoadFailed,
        ),
      );
      return;
    }
    final deposit = detail.data!;
    // "Renew principal and interest" pays nothing out — OBDX skips the
    // payout call for it, and so does the screen.
    final noPayout =
        deposit.rollOverType == TdRollOver.renewPrincipalAndInterest;
    state = TdDetailState(
      deposit: deposit,
      payouts: noPayout
          ? const []
          : payouts is Success<List<TdPayoutInstruction>>
              ? payouts.data ?? const []
              : null,
      payoutsError: noPayout || payouts is Success
          ? null
          : payouts.resolveUserMessage(
              l10n: l10n,
              fallback: l10n.tdPayoutLoadFailed,
            ),
    );
  }
}

final termDepositDetailProvider = StateNotifierProvider.autoDispose
    .family<TdDetailNotifier, TdDetailState, String>(
  (ref, id) => TdDetailNotifier(ref, id),
);

/// A transactions search.
class TdTransactionsQuery {
  const TdTransactionsQuery({
    required this.depositId,
    this.period = TdTransactionPeriod.currentMonth,
    this.type = 'A',
  });

  final String depositId;
  final TdTransactionPeriod period;

  /// `A` all, `C` credits, `D` debits.
  final String type;

  @override
  bool operator ==(Object other) =>
      other is TdTransactionsQuery &&
      other.depositId == depositId &&
      other.period == period &&
      other.type == type;

  @override
  int get hashCode => Object.hash(depositId, period, type);
}

final termDepositTransactionsProvider = FutureProvider.autoDispose
    .family<List<AccountTransaction>, TdTransactionsQuery>((ref, q) async {
  final l10n = await AppLocalizationsHelper.current();
  final result = await ref
      .read(termDepositRepositoryProvider)
      .fetchTransactions(q.depositId,
          period: q.period, transactionType: q.type);
  if (result is Success<List<AccountTransaction>>) {
    return result.data ?? const [];
  }
  throw result.resolveUserMessage(
    l10n: l10n,
    fallback: l10n.tdTransactionsLoadFailed,
  );
});

// ── Lookups for the actions ──────────────────────────────────────────────

/// An OBDX TD enumeration (`rollOverType`, `payOutOption`) — empty when
/// the call fails, so the screens fall back to the captured labels.
final tdEnumerationProvider =
    FutureProvider.family<List<TdEnumOption>, String>((ref, name) async {
  final result =
      await ref.read(termDepositRepositoryProvider).fetchEnumeration(name);
  return result is Success<List<TdEnumOption>> ? result.data ?? const [] : [];
});

/// The roll-over options with their OBDX descriptions.
final tdRollOverOptionsProvider =
    FutureProvider.autoDispose<List<TdEnumOption>>((ref) async {
  final options = await ref.watch(tdEnumerationProvider('rollOverType').future);
  if (options.isNotEmpty) return options;
  return [
    for (final MapEntry(:key, :value) in TdRollOver.fallbackLabels.entries)
      TdEnumOption(code: key, description: value),
  ];
});

/// CASA accounts an action may use, by OBDX task code ([TdTask]).
final tdPayAccountsProvider = FutureProvider.autoDispose
    .family<List<TdPayAccount>, String>((ref, taskCode) async {
  final l10n = await AppLocalizationsHelper.current();
  final result =
      await ref.read(termDepositRepositoryProvider).fetchPayAccounts(taskCode);
  if (result is Success<List<TdPayAccount>>) return result.data ?? const [];
  throw result.resolveUserMessage(
    l10n: l10n,
    fallback: l10n.errorAccountsLoadFailed,
  );
});

/// The deposits an action allows, by OBDX task code.
final tdEligibleDepositsProvider = FutureProvider.autoDispose
    .family<List<TermDeposit>, String>((ref, taskCode) async {
  final l10n = await AppLocalizationsHelper.current();
  final result =
      await ref.read(termDepositRepositoryProvider).fetchDepositsFor(taskCode);
  if (result is Success<List<TermDeposit>>) return result.data ?? const [];
  throw result.resolveUserMessage(l10n: l10n, fallback: l10n.tdLoadFailed);
});

/// A branch's name and address — best-effort (null on failure).
final tdBranchProvider =
    FutureProvider.family<TdBranch?, String>((ref, code) async {
  final result =
      await ref.read(termDepositRepositoryProvider).fetchBranch(code);
  return result is Success<TdBranch?> ? result.data : null;
});

final tdProductsProvider =
    FutureProvider.autoDispose<List<TdProduct>>((ref) async {
  final l10n = await AppLocalizationsHelper.current();
  final result = await ref.read(termDepositRepositoryProvider).fetchProducts();
  if (result is Success<List<TdProduct>>) return result.data ?? const [];
  throw result.resolveUserMessage(
    l10n: l10n,
    fallback: l10n.tdProductsLoadFailed,
  );
});

/// The bank's business date (`common/v1/currentDate`), for "matures in"
/// countdowns — test hosts run on a fixed date. Falls back to today.
final tdBusinessDateProvider = FutureProvider<DateTime>((ref) async {
  final result =
      await ref.read(accountsRepositoryProvider).fetchCurrentBankingDate();
  if (result is Success<BankingDate> && result.data?.currentDate != null) {
    return result.data!.currentDate!;
  }
  return DateTime.now();
});

// ── Confirming an action ────────────────────────────────────────────────

/// One confirm attempt: [otp]/[challenge] are set on the OTP retry.
typedef TdSubmitAttempt = Future<ResponseHandler<TdSubmitOutcome>> Function(
  String? otp,
  ObdxChallenge? challenge,
);

class TdSubmissionState {
  const TdSubmissionState({
    this.isSubmitting = false,
    this.result,
    this.errorMessage,
    this.challenge,
    this.otpError,
  });

  final bool isSubmitting;
  final TdSubmitted? result;
  final String? errorMessage;

  /// Set while OBDX waits for an OTP.
  final ObdxChallenge? challenge;

  /// Shown on the OTP sheet (e.g. a wrong code).
  final String? otpError;
}

/// Confirms a TD action, handling OBDX's OTP step the way loan repayment
/// does: a first 417 opens the OTP sheet, a second means the code was
/// wrong, and a failure while verifying keeps the sheet open.
class TdSubmissionNotifier extends StateNotifier<TdSubmissionState> {
  TdSubmissionNotifier() : super(const TdSubmissionState());

  TdSubmitAttempt? _attempt;

  Future<void> submit(TdSubmitAttempt attempt) async {
    _attempt = attempt;
    state = const TdSubmissionState(isSubmitting: true);
    await _run();
  }

  Future<void> verifyOtp(String otp) async {
    final challenge = state.challenge;
    if (challenge == null) return;
    state = TdSubmissionState(isSubmitting: true, challenge: challenge);
    await _run(otp: otp, challenge: challenge);
  }

  Future<void> _run({String? otp, ObdxChallenge? challenge}) async {
    final attempt = _attempt;
    if (attempt == null) return;
    final l10n = await AppLocalizationsHelper.current();
    final result = await attempt(otp, challenge);
    if (!mounted) return;

    if (result is Success<TdSubmitOutcome>) {
      switch (result.data) {
        case TdSubmitted done:
          state = TdSubmissionState(result: done);
          return;
        case TdNeedsOtp(challenge: final next):
          state = TdSubmissionState(
            challenge: next,
            otpError: otp != null ? l10n.loanRepaymentOtpIncorrect : null,
          );
          return;
        case null:
          break;
      }
    }
    final message = result.resolveUserMessage(
      l10n: l10n,
      fallback: l10n.tdActionFailed,
    );
    state = otp != null && challenge != null
        ? TdSubmissionState(challenge: challenge, otpError: message)
        : TdSubmissionState(errorMessage: message);
  }

  void reset() {
    _attempt = null;
    state = const TdSubmissionState();
  }
}

final tdSubmissionProvider =
    StateNotifierProvider.autoDispose<TdSubmissionNotifier, TdSubmissionState>(
  (ref) => TdSubmissionNotifier(),
);
