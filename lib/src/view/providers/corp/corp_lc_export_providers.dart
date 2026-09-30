import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';

/// Submission state shared by the Export LC actions (amendment acceptance
/// and transfer). Mirrors the initiate / amend flows: submit → optional
/// OTP challenge → outcome.
class LcActionState<T> {
  const LcActionState({
    this.isLoading = false,
    this.data,
    this.isSubmitting = false,
    this.errorMessage,
    this.challenge,
    this.otpError,
    this.outcome,
  });

  final bool isLoading;

  /// The form model (a transfer draft) — null for actions without a form.
  final T? data;
  final bool isSubmitting;
  final String? errorMessage;
  final ObdxChallenge? challenge;
  final String? otpError;
  final LcSubmitted? outcome;

  LcActionState<T> copyWith({
    bool? isLoading,
    T? data,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    ObdxChallenge? challenge,
    bool clearChallenge = false,
    String? otpError,
    bool clearOtpError = false,
    LcSubmitted? outcome,
  }) {
    return LcActionState<T>(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      challenge: clearChallenge ? null : (challenge ?? this.challenge),
      otpError: (clearChallenge || clearOtpError)
          ? null
          : (otpError ?? this.otpError),
      outcome: outcome ?? this.outcome,
    );
  }
}

/// Common submit/OTP handling for the Export actions.
abstract class LcActionNotifier<T> extends StateNotifier<LcActionState<T>> {
  LcActionNotifier(this.ref, LcActionState<T> initial) : super(initial);

  final Ref ref;

  /// Performs the host call for this action.
  Future<ResponseHandler<LcSubmitOutcome>> send({
    ObdxChallenge? challenge,
    String? otp,
  });

  /// Called once the host accepted the request.
  void onSubmitted() {}

  String get failureFallback;

  Future<void> run({String? otp}) async {
    final generation = SessionGeneration.current;
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await send(
      challenge: otp == null ? null : state.challenge,
      otp: otp,
    );
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;

    if (result is Success<LcSubmitOutcome>) {
      switch (result.data) {
        case LcAwaitingOtp(:final challenge):
          state = state.copyWith(
            isSubmitting: false,
            challenge: challenge,
            otpError: otp == null ? null : 'Incorrect code. Please try again.',
            clearOtpError: otp == null,
          );
          return;
        case final LcSubmitted submitted:
          state = state.copyWith(
            isSubmitting: false,
            clearChallenge: true,
            outcome: submitted,
          );
          onSubmitted();
          return;
        case null:
          break;
      }
    }
    final message = await lcFailureMessage(result, fallback: failureFallback);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = otp != null && state.challenge != null
        ? state.copyWith(isSubmitting: false, otpError: message)
        : state.copyWith(
            isSubmitting: false,
            clearChallenge: true,
            errorMessage: message,
          );
  }

  void cancelOtp() => state = state.copyWith(clearChallenge: true);
}

// ── LC amendment acceptance ─────────────────────────────────────────────

class CorpLcAcceptanceNotifier extends LcActionNotifier<Object> {
  CorpLcAcceptanceNotifier(Ref ref, this.amendment)
      : super(ref, const LcActionState<Object>());

  final CorpLcAmendment amendment;

  bool _accept = true;
  String? _remarks;

  Future<void> respond({
    required bool accept,
    String? remarks,
    String? otp,
  }) {
    _accept = accept;
    _remarks = remarks;
    return run(otp: otp);
  }

  /// Re-sends the last decision with the OTP.
  Future<void> submitOtp(String otp) =>
      respond(accept: _accept, remarks: _remarks, otp: otp);

  bool get lastDecisionAccepted => _accept;

  @override
  Future<ResponseHandler<LcSubmitOutcome>> send({
    ObdxChallenge? challenge,
    String? otp,
  }) {
    return ref.read(corpTradeFinanceRepositoryProvider).respondToAmendment(
          amendment,
          accept: _accept,
          remarks: _remarks,
          challenge: challenge,
          otp: otp,
        );
  }

  @override
  void onSubmitted() {
    if (ref.exists(corpLcExportAmendmentsProvider)) {
      ref.read(corpLcExportAmendmentsProvider.notifier).refresh();
    }
  }

  @override
  String get failureFallback => 'Could not send your response.';
}

/// Keyed by the amendment instance from the acceptance list (passed on as
/// the route argument), so the screen and the list share one object.
final corpLcAcceptanceProvider = StateNotifierProvider.autoDispose
    .family<CorpLcAcceptanceNotifier, LcActionState<Object>, CorpLcAmendment>(
  (ref, amendment) => CorpLcAcceptanceNotifier(ref, amendment),
);

// ── Initiate transfer LC ────────────────────────────────────────────────

class CorpLcTransferNotifier extends LcActionNotifier<LcTransferDraft> {
  CorpLcTransferNotifier(Ref ref, this.lcId)
      : super(ref, const LcActionState<LcTransferDraft>(isLoading: true)) {
    load();
  }

  final String lcId;

  Future<void> load() async {
    final generation = SessionGeneration.current;
    state = const LcActionState<LcTransferDraft>(isLoading: true);
    final result = await ref
        .read(corpTradeFinanceRepositoryProvider)
        .fetchLetterOfCredit(lcId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    if (result is Success<CorpLetterOfCredit> && result.data != null) {
      state = LcActionState<LcTransferDraft>(
        data: LcTransferDraft.fromLetterOfCredit(result.data!),
      );
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not load the letter of credit.',
    );
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = LcActionState<LcTransferDraft>(errorMessage: message);
  }

  void update(LcTransferDraft Function(LcTransferDraft d) change) {
    final d = state.data;
    if (d == null) return;
    state = state.copyWith(data: change(d), clearError: true);
  }

  List<String> validate() {
    final d = state.data;
    if (d == null) return const ['The LC has not loaded yet.'];
    final errors = <String>[];
    final max = d.maxAmount;
    if (d.amount == null || d.amount! <= 0) {
      errors.add('Enter the amount to transfer.');
    } else if (max != null && d.amount! > max) {
      errors.add('Transfer amount cannot exceed the available amount.');
    }
    if ((d.beneficiaryName ?? '').trim().isEmpty) {
      errors.add('Enter the second beneficiary name.');
    }
    if ((d.beneficiaryAddress.line1 ?? '').trim().isEmpty) {
      errors.add('Enter the second beneficiary address.');
    }
    if (d.beneficiaryAddress.country == null) {
      errors.add('Select the second beneficiary country.');
    }
    final ship = d.latestShipmentDate;
    final originalShip = d.original.shipment.latestShipmentDate;
    if (ship != null && d.expiryDate != null && ship.isAfter(d.expiryDate!)) {
      errors.add('Latest shipment date cannot be after the expiry date.');
    }
    if (ship != null && originalShip != null && ship.isAfter(originalShip)) {
      errors.add('Latest shipment date cannot be later than the original LC.');
    }
    final originalExpiry = d.original.expiryDate;
    if (d.expiryDate != null &&
        originalExpiry != null &&
        d.expiryDate!.isAfter(originalExpiry)) {
      errors.add('Expiry date cannot be later than the original LC.');
    }
    return errors;
  }

  Future<List<String>> submit({String? otp}) async {
    if (otp == null) {
      final errors = validate();
      if (errors.isNotEmpty) return errors;
    }
    await run(otp: otp);
    return const [];
  }

  @override
  Future<ResponseHandler<LcSubmitOutcome>> send({
    ObdxChallenge? challenge,
    String? otp,
  }) {
    return ref.read(corpTradeFinanceRepositoryProvider).submitTransfer(
          lcId,
          state.data!.toRequestJson(partyId: currentLcParty(ref)),
          challenge: challenge,
          otp: otp,
        );
  }

  @override
  void onSubmitted() {
    refreshLcListIfOpen(ref, LcListKind.transferable);
    refreshLcListIfOpen(ref, LcListKind.transferred);
  }

  @override
  String get failureFallback => 'Could not submit the transfer.';
}

final corpLcTransferProvider = StateNotifierProvider.autoDispose.family<
    CorpLcTransferNotifier, LcActionState<LcTransferDraft>, String>(
  (ref, lcId) => CorpLcTransferNotifier(ref, lcId),
);
