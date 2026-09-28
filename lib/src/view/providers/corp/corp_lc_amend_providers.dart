import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';

class CorpLcAmendState {
  const CorpLcAmendState({
    this.isLoading = true,
    this.draft,
    this.reviewing = false,
    this.charges,
    this.chargesLoading = false,
    this.chargesMessage,
    this.isSubmitting = false,
    this.errorMessage,
    this.challenge,
    this.otpError,
    this.outcome,
  });

  final bool isLoading;

  /// Null until the original LC has loaded.
  final LcAmendmentDraft? draft;

  /// Form (false) or review (true).
  final bool reviewing;

  final List<LcCharge>? charges;
  final bool chargesLoading;
  final String? chargesMessage;
  final bool isSubmitting;
  final String? errorMessage;
  final ObdxChallenge? challenge;
  final String? otpError;
  final LcSubmitted? outcome;

  CorpLcAmendState copyWith({
    bool? isLoading,
    LcAmendmentDraft? draft,
    bool? reviewing,
    List<LcCharge>? charges,
    bool clearCharges = false,
    bool? chargesLoading,
    String? chargesMessage,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    ObdxChallenge? challenge,
    bool clearChallenge = false,
    String? otpError,
    bool clearOtpError = false,
    LcSubmitted? outcome,
  }) {
    return CorpLcAmendState(
      isLoading: isLoading ?? this.isLoading,
      draft: draft ?? this.draft,
      reviewing: reviewing ?? this.reviewing,
      charges: clearCharges ? null : (charges ?? this.charges),
      chargesLoading: chargesLoading ?? this.chargesLoading,
      chargesMessage:
          clearCharges ? null : (chargesMessage ?? this.chargesMessage),
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

/// Import LC amendment — loads the live LC (H1 #141), lets the user change
/// the amendable fields, previews charges (H1 #177) and submits (H1 #204).
class CorpLcAmendNotifier extends StateNotifier<CorpLcAmendState> {
  CorpLcAmendNotifier(this._ref, this.lcId) : super(const CorpLcAmendState()) {
    load();
  }

  final Ref _ref;
  final String lcId;

  Future<void> load() async {
    final generation = SessionGeneration.current;
    state = const CorpLcAmendState();
    final result = await _ref
        .read(corpTradeFinanceRepositoryProvider)
        .fetchLetterOfCredit(lcId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    if (result is Success<CorpLetterOfCredit> && result.data != null) {
      state = CorpLcAmendState(
        isLoading: false,
        draft: LcAmendmentDraft.fromLetterOfCredit(result.data!),
      );
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not load the letter of credit.',
    );
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = CorpLcAmendState(isLoading: false, errorMessage: message);
  }

  void update(LcAmendmentDraft Function(LcAmendmentDraft draft) change) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(
      draft: change(draft),
      clearError: true,
      clearCharges: true,
    );
  }

  List<String> validate() {
    final d = state.draft;
    if (d == null) return const ['The LC has not loaded yet.'];
    final errors = <String>[];
    if (d.newAmount == null || d.newAmount! <= 0) {
      errors.add('Enter an LC amount greater than zero.');
    }
    if (d.newExpiryDate == null) errors.add('Select the expiry date.');
    final ship = d.shipment.latestShipmentDate;
    if (ship != null && d.newExpiryDate != null && ship.isAfter(d.newExpiryDate!)) {
      errors.add('Latest shipment date cannot be after the expiry date.');
    }
    if (d.changes.isEmpty) errors.add('Change at least one field to amend.');
    return errors;
  }

  List<String> review() {
    final errors = validate();
    if (errors.isNotEmpty) return errors;
    state = state.copyWith(reviewing: true, clearError: true);
    _loadCharges();
    return const [];
  }

  void backToForm() =>
      state = state.copyWith(reviewing: false, clearError: true);

  Future<void> _loadCharges() async {
    final draft = state.draft;
    if (draft == null) return;
    final generation = SessionGeneration.current;
    state = state.copyWith(chargesLoading: true, clearCharges: true);
    final result = await _ref
        .read(corpTradeFinanceRepositoryProvider)
        .previewAmendmentCharges(
          lcId,
          draft.toRequestJson(partyId: currentLcParty(_ref)),
        );
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    if (result is Success<List<LcCharge>>) {
      state = state.copyWith(chargesLoading: false, charges: result.data ?? []);
      return;
    }
    state = state.copyWith(
      chargesLoading: false,
      charges: const [],
      chargesMessage:
          'Charges could not be previewed. The bank will apply the applicable amendment charges.',
    );
  }

  Future<void> submit({String? otp}) async {
    final draft = state.draft;
    if (draft == null) return;
    final generation = SessionGeneration.current;
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await _ref
        .read(corpTradeFinanceRepositoryProvider)
        .submitAmendment(
          lcId,
          draft.toRequestJson(partyId: currentLcParty(_ref)),
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
          refreshLcListIfOpen(_ref, LcListKind.importLc);
          refreshLcListIfOpen(_ref, LcListKind.amendable);
          _ref.invalidate(corpLcDetailProvider(lcId));
          return;
        case null:
          break;
      }
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not submit the amendment.',
    );
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

final corpLcAmendProvider = StateNotifierProvider.autoDispose
    .family<CorpLcAmendNotifier, CorpLcAmendState, String>(
  (ref, lcId) => CorpLcAmendNotifier(ref, lcId),
);
