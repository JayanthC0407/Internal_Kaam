import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_trade_finance_repository.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';

/// Wizard steps, in order. Mirrors the OBDX web initiation sections
/// (LC details → parties/banks → shipment → documents → review).
enum LcInitiateStep {
  details('LC Details'),
  parties('Beneficiary & Bank'),
  shipment('Shipment & Goods'),
  documents('Documents & Conditions'),
  review('Review');

  const LcInitiateStep(this.label);
  final String label;
}

class CorpLcInitiateState {
  const CorpLcInitiateState({
    this.step = LcInitiateStep.details,
    this.draft = LcInitiateDraft.empty,
    this.productDocuments = const [],
    this.documentsLoading = false,
    this.draftId,
    this.isSaving = false,
    this.isSubmitting = false,
    this.isLookingUpBic = false,
    this.bicMessage,
    this.charges,
    this.chargesLoading = false,
    this.chargesMessage,
    this.errorMessage,
    this.infoMessage,
    this.challenge,
    this.otpError,
    this.outcome,
  });

  final LcInitiateStep step;
  final LcInitiateDraft draft;

  /// Documents offered by the selected product (H1 #159).
  final List<LcDocument> productDocuments;
  final bool documentsLoading;

  /// Host id of the saved draft (`"1"` in H1 #71); null until first save.
  final String? draftId;

  final bool isSaving;
  final bool isSubmitting;
  final bool isLookingUpBic;
  final String? bicMessage;

  /// Charge preview for the review step; null = not requested yet.
  final List<LcCharge>? charges;
  final bool chargesLoading;
  final String? chargesMessage;

  final String? errorMessage;
  final String? infoMessage;

  /// Set while the host waits for an OTP.
  final ObdxChallenge? challenge;
  final String? otpError;

  /// Set once the LC has been submitted — the screen shows the result.
  final LcSubmitted? outcome;

  bool get isBusy => isSaving || isSubmitting;

  CorpLcInitiateState copyWith({
    LcInitiateStep? step,
    LcInitiateDraft? draft,
    List<LcDocument>? productDocuments,
    bool? documentsLoading,
    String? draftId,
    bool? isSaving,
    bool? isSubmitting,
    bool? isLookingUpBic,
    String? bicMessage,
    bool clearBicMessage = false,
    List<LcCharge>? charges,
    bool clearCharges = false,
    bool? chargesLoading,
    String? chargesMessage,
    String? errorMessage,
    String? infoMessage,
    bool clearMessages = false,
    ObdxChallenge? challenge,
    bool clearChallenge = false,
    String? otpError,
    bool clearOtpError = false,
    LcSubmitted? outcome,
  }) {
    return CorpLcInitiateState(
      step: step ?? this.step,
      draft: draft ?? this.draft,
      productDocuments: productDocuments ?? this.productDocuments,
      documentsLoading: documentsLoading ?? this.documentsLoading,
      draftId: draftId ?? this.draftId,
      isSaving: isSaving ?? this.isSaving,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLookingUpBic: isLookingUpBic ?? this.isLookingUpBic,
      bicMessage: clearBicMessage ? null : (bicMessage ?? this.bicMessage),
      charges: clearCharges ? null : (charges ?? this.charges),
      chargesLoading: chargesLoading ?? this.chargesLoading,
      chargesMessage:
          clearCharges ? null : (chargesMessage ?? this.chargesMessage),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearMessages ? null : (infoMessage ?? this.infoMessage),
      challenge: clearChallenge ? null : (challenge ?? this.challenge),
      otpError: (clearChallenge || clearOtpError)
          ? null
          : (otpError ?? this.otpError),
      outcome: outcome ?? this.outcome,
    );
  }
}

class CorpLcInitiateNotifier extends StateNotifier<CorpLcInitiateState> {
  CorpLcInitiateNotifier(this._ref) : super(const CorpLcInitiateState());

  final Ref _ref;

  CorpTradeFinanceRepository get _repo =>
      _ref.read(corpTradeFinanceRepositoryProvider);

  // ── Form editing ─────────────────────────────────────────────────────

  /// Seeds from an existing LC ("Copy & initiate") or a saved draft.
  /// [draftId] is passed for a draft so later saves update it in place.
  void seed(CorpLetterOfCredit lc, {String? draftId}) {
    final products = _ref.read(corpLcLookupsProvider).lookups.products;
    LcProduct? product;
    for (final p in products) {
      if (p.id == lc.productId) product = p;
    }
    state = CorpLcInitiateState(
      draft: LcInitiateDraft.fromLetterOfCredit(lc, product: product),
      draftId: draftId,
    );
    final id = lc.productId;
    if (id != null) _loadProductDocuments(id);
  }

  // ── Prefill sources (Initiate LC tabs) ───────────────────────────────

  /// By Drafts — the drafts list may carry summaries only, so the full draft
  /// is read (OBDX spec `readDraft`); the list row is the fallback.
  Future<void> seedFromDraft(String draftId, CorpLetterOfCredit row) async {
    final generation = SessionGeneration.current;
    final result = await _repo.fetchDraft(draftId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    final lc = _dataOr(result, row);
    seed(lc, draftId: draftId);
    // A Back to Back draft keeps its backing Export LC.
    final parents = lc.raw['parentReferenceLCs'];
    if (parents is List && parents.isNotEmpty) {
      final parent = TfJson.str(parents.first);
      if (parent != null) {
        state = state.copyWith(draft: state.draft.copyWith(parentLcId: parent));
      }
    }
  }

  /// By Template — prefills a *new* LC; the template itself is untouched,
  /// so no draft id and no draft name are carried over.
  Future<void> seedFromTemplate(String templateId, CorpLetterOfCredit row) async {
    final generation = SessionGeneration.current;
    final result = await _repo.fetchTemplate(templateId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    seed(_dataOr(result, row));
    state = state.copyWith(draft: _withoutName(state.draft));
  }

  /// Copy & Initiate — the full LC is read (H1 #48) and duplicated.
  Future<void> seedFromLc(String lcId, CorpLetterOfCredit row) async {
    final generation = SessionGeneration.current;
    final result = await _repo.fetchLetterOfCredit(lcId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    seed(_dataOr(result, row));
    state = state.copyWith(draft: _withoutName(state.draft));
  }

  /// Back to Back LC — a new Import LC backed by [exportLc]. Currency,
  /// goods, shipment and incoterm follow the export LC; beneficiary and
  /// amount are left for the user (the supplier and the cost price differ
  /// from the export side).
  Future<void> seedBackToBack(CorpLetterOfCredit exportLc) async {
    final generation = SessionGeneration.current;
    final result = await _repo.fetchLetterOfCredit(exportLc.id);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    final source = _dataOr(result, exportLc);
    state = CorpLcInitiateState(
      draft: LcInitiateDraft(
        currency: source.amount?.currency,
        expiryDate: source.expiryDate,
        shipment: source.shipment,
        incoterm: (source.incoterm?.code.isEmpty ?? true) ? null : source.incoterm,
        goods: source.goods,
        parentLcId: source.id,
      ),
    );
  }

  static CorpLetterOfCredit _dataOr(
    ResponseHandler<CorpLetterOfCredit> result,
    CorpLetterOfCredit fallback,
  ) =>
      (result is Success<CorpLetterOfCredit> ? result.data : null) ?? fallback;

  /// A copy must not reuse the source's draft/template name.
  static LcInitiateDraft _withoutName(LcInitiateDraft d) => LcInitiateDraft(
        product: d.product,
        currency: d.currency,
        amount: d.amount,
        expiryDate: d.expiryDate,
        expiryPlace: d.expiryPlace,
        toleranceAbove: d.toleranceAbove,
        toleranceUnder: d.toleranceUnder,
        availableBy: d.availableBy,
        confirmationInstruction: d.confirmationInstruction,
        documentPresentationDays: d.documentPresentationDays,
        beneficiaryName: d.beneficiaryName,
        beneficiaryAddress: d.beneficiaryAddress,
        advisingBank: d.advisingBank,
        advisingBankCode: d.advisingBankCode,
        chargesBorneBy: d.chargesBorneBy,
        shipment: d.shipment,
        incoterm: d.incoterm,
        goods: d.goods,
        documents: d.documents,
        additionalConditions: d.additionalConditions,
        instructions: d.instructions,
        parentLcId: d.parentLcId,
      );

  void update(LcInitiateDraft Function(LcInitiateDraft draft) change) {
    state = state.copyWith(
      draft: change(state.draft),
      clearMessages: true,
      clearCharges: true,
    );
  }

  /// Selecting a product applies its tolerance defaults and loads the
  /// documents it allows.
  void selectProduct(LcProduct product) {
    update((d) => d.copyWith(
          product: product,
          toleranceAbove: product.positiveTolerance,
          toleranceUnder: product.negativeTolerance,
          documents: const [],
        ));
    _loadProductDocuments(product.id);
  }

  Future<void> _loadProductDocuments(String productId) async {
    final generation = SessionGeneration.current;
    state = state.copyWith(documentsLoading: true, productDocuments: const []);
    final result = await _repo.fetchProductDocuments(productId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = state.copyWith(
      documentsLoading: false,
      productDocuments: result is Success<List<LcDocument>>
          ? (result.data ?? const [])
          : const [],
    );
  }

  void toggleDocument(LcDocument document, bool selected) {
    final current = [...state.draft.documents]
      ..removeWhere((d) => d.id == document.id);
    if (selected) current.add(document);
    update((d) => d.copyWith(documents: current));
  }

  void updateDocument(LcDocument document) {
    update((d) => d.copyWith(documents: [
          for (final doc in d.documents) doc.id == document.id ? document : doc,
        ]));
  }

  void toggleCondition(TradeCode condition, bool selected) {
    final current = [...state.draft.additionalConditions]
      ..removeWhere((c) => c.code == condition.code);
    if (selected) current.add(condition);
    update((d) => d.copyWith(additionalConditions: current));
  }

  void addGoods(LcGoods goods) =>
      update((d) => d.copyWith(goods: [...d.goods, goods]));

  void removeGoodsAt(int index) {
    final list = [...state.draft.goods]..removeAt(index);
    update((d) => d.copyWith(goods: list));
  }

  /// Resolves the advising bank SWIFT code via `tradeBicCodes` (H1 #143).
  Future<void> lookupAdvisingBank(String code) async {
    final swift = code.trim().toUpperCase();
    if (swift.length != 8 && swift.length != 11) {
      state = state.copyWith(bicMessage: 'Enter an 8 or 11 character SWIFT code.');
      return;
    }
    final generation = SessionGeneration.current;
    state = state.copyWith(isLookingUpBic: true, clearBicMessage: true);
    final result = await _repo.lookupBic(swift);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;

    if (result is Success<TradeBank?> && result.data != null) {
      final bank = result.data!;
      state = state.copyWith(
        isLookingUpBic: false,
        draft: state.draft.copyWith(advisingBank: bank, advisingBankCode: swift),
      );
      return;
    }
    state = state.copyWith(
      isLookingUpBic: false,
      draft: state.draft
          .copyWith(advisingBankCode: swift, clearAdvisingBank: true),
      bicMessage: result is Success
          ? 'No bank found for $swift.'
          : (await lcFailureMessage(result, fallback: 'Bank lookup failed.')),
    );
  }

  // ── Navigation & validation ──────────────────────────────────────────

  /// Client-side checks for [step]. The host re-validates everything on
  /// submit (limits, product rules, dates), so this only catches what the
  /// user can fix without a round trip.
  List<String> validate(LcInitiateStep step) {
    final d = state.draft;
    final errors = <String>[];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    switch (step) {
      case LcInitiateStep.details:
        if (d.product == null) errors.add('Select an LC product.');
        if ((d.currency ?? '').length != 3) errors.add('Select the LC currency.');
        if (d.amount == null || d.amount! <= 0) {
          errors.add('Enter an LC amount greater than zero.');
        }
        if (d.expiryDate == null) {
          errors.add('Select the expiry date.');
        } else if (!d.expiryDate!.isAfter(todayDate)) {
          errors.add('Expiry date must be in the future.');
        }
        if ((d.expiryPlace ?? '').trim().isEmpty) {
          errors.add('Enter the place of expiry.');
        }
      case LcInitiateStep.parties:
        if ((d.beneficiaryName ?? '').trim().isEmpty) {
          errors.add('Enter the beneficiary name.');
        }
        if ((d.beneficiaryAddress.line1 ?? '').trim().isEmpty) {
          errors.add('Enter the beneficiary address.');
        }
        if (d.beneficiaryAddress.country == null) {
          errors.add('Select the beneficiary country.');
        }
        final code = (d.advisingBankCode ?? '').trim();
        if (code.length != 8 && code.length != 11) {
          errors.add('Enter the advising bank SWIFT code (8 or 11 characters).');
        }
      case LcInitiateStep.shipment:
        final s = d.shipment;
        if ((s.loadingPort ?? '').trim().isEmpty) {
          errors.add('Enter the port of loading.');
        }
        if ((s.dischargePort ?? '').trim().isEmpty) {
          errors.add('Enter the port of discharge.');
        }
        if (s.latestShipmentDate != null &&
            d.expiryDate != null &&
            s.latestShipmentDate!.isAfter(d.expiryDate!)) {
          errors.add('Latest shipment date cannot be after the expiry date.');
        }
      case LcInitiateStep.documents:
      case LcInitiateStep.review:
        break;
    }
    return errors;
  }

  /// Validates the current step and moves forward. Returns the errors (an
  /// empty list means the step changed).
  List<String> next() {
    final errors = validate(state.step);
    if (errors.isNotEmpty) return errors;
    final nextIndex = state.step.index + 1;
    if (nextIndex < LcInitiateStep.values.length) {
      state = state.copyWith(
        step: LcInitiateStep.values[nextIndex],
        clearMessages: true,
      );
      if (state.step == LcInitiateStep.review) loadCharges();
    }
    return const [];
  }

  void back() {
    if (state.step.index == 0) return;
    state = state.copyWith(
      step: LcInitiateStep.values[state.step.index - 1],
      clearMessages: true,
    );
  }

  /// Jump back to an earlier step from the review screen.
  void goTo(LcInitiateStep step) {
    if (step.index > state.step.index) return;
    state = state.copyWith(step: step, clearMessages: true);
  }

  // ── Host calls ───────────────────────────────────────────────────────

  Map<String, dynamic> _body({
    required String lcState,
    String? id,
    bool autoSaved = false,
  }) {
    final lookups = _ref.read(corpLcLookupsProvider).lookups;
    return state.draft.toRequestJson(
      partyId: currentLcParty(_ref),
      partyName: currentLcPartyName(_ref),
      branchId: lookups.configuration.branchCode,
      state: lcState,
      id: id,
      autoSaved: autoSaved,
    );
  }

  /// Charge preview (H1 #121). Failure is informational only — the bank
  /// still computes charges on submit.
  Future<void> loadCharges() async {
    final generation = SessionGeneration.current;
    state = state.copyWith(chargesLoading: true, clearCharges: true);
    final result = await _repo.previewCharges(_body(lcState: 'INITIATED'));
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    if (result is Success<List<LcCharge>>) {
      state = state.copyWith(chargesLoading: false, charges: result.data ?? []);
      return;
    }
    state = state.copyWith(
      chargesLoading: false,
      charges: const [],
      chargesMessage:
          'Charges could not be previewed. The bank will apply the applicable charges on processing.',
    );
  }

  /// Saves (POST, then PUT) the current form as a draft — H1 #71 / #74.
  Future<bool> saveDraft() async {
    final generation = SessionGeneration.current;
    state = state.copyWith(isSaving: true, clearMessages: true);
    final name = state.draft.draftName ?? _generatedDraftName();
    if (state.draft.draftName == null) {
      state = state.copyWith(draft: state.draft.copyWith(draftName: name));
    }
    final result = await _repo.saveDraft(
      _body(lcState: 'DRAFT', id: state.draftId),
      draftId: state.draftId,
    );
    if (!SessionGeneration.isCurrent(generation) || !mounted) return false;

    if (result is Success<String> && result.data != null) {
      state = state.copyWith(
        isSaving: false,
        draftId: result.data,
        infoMessage: 'Draft "$name" saved.',
      );
      refreshLcListIfOpen(_ref, LcListKind.drafts);
      return true;
    }
    state = state.copyWith(
      isSaving: false,
      errorMessage:
          await lcFailureMessage(result, fallback: 'Could not save the draft.'),
    );
    return false;
  }

  /// Discards the saved draft (H1 #80), if there is one.
  Future<void> discardDraft() async {
    final id = state.draftId;
    if (id == null) return;
    await _repo.deleteDraft(id);
    refreshLcListIfOpen(_ref, LcListKind.drafts);
  }
    /// User-initiated delete of the draft being edited. Returns true on success.
  Future<bool> deleteCurrentDraft() async {
    final id = state.draftId;
    if (id == null) return false;
    final generation = SessionGeneration.current;
    state = state.copyWith(isSaving: true, clearMessages: true);
    final result = await _repo.deleteDraft(id);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return false;

    if (result is Success<bool>) {
      state = state.copyWith(isSaving: false);
      refreshLcListIfOpen(_ref, LcListKind.drafts);
      return true;
    }
    state = state.copyWith(
      isSaving: false,
      errorMessage: await lcFailureMessage(
        result,
        fallback: 'Could not delete the draft.',
      ),
    );
    return false;
  }
  /// Submits the LC; call again with [otp] after an [LcAwaitingOtp].
  Future<void> submit({String? otp}) async {
    for (final step in LcInitiateStep.values) {
      final errors = validate(step);
      if (errors.isNotEmpty) {
        state = state.copyWith(step: step, errorMessage: errors.first);
        return;
      }
    }
    final generation = SessionGeneration.current;
    state = state.copyWith(isSubmitting: true, clearMessages: true);
    final result = await _repo.submitInitiation(
      _body(lcState: 'INITIATED'),
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
          // The draft (if any) has served its purpose.
          await discardDraft();
          if (!mounted) return;
          state = state.copyWith(
            isSubmitting: false,
            clearChallenge: true,
            outcome: submitted,
          );
          refreshLcListIfOpen(_ref, LcListKind.importLc);
          return;
        case null:
          break;
      }
    }
    final message =
        await lcFailureMessage(result, fallback: 'Could not submit the LC.');
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

  /// `LC_CREATE_<party 4>_<4 digits>` — the pattern the web uses
  /// (`LC_CREATE_18BA_2189`, H1 #71).
  String _generatedDraftName() {
    final party = currentLcParty(_ref).value ?? '';
    final tag = party.length >= 6 ? party.substring(2, 6) : 'CORP';
    final stamp = DateTime.now().millisecondsSinceEpoch % 10000;
    return 'LC_CREATE_${tag}_${stamp.toString().padLeft(4, '0')}';
  }
}

final corpLcInitiateProvider = StateNotifierProvider.autoDispose<
    CorpLcInitiateNotifier, CorpLcInitiateState>(
  (ref) => CorpLcInitiateNotifier(ref),
);
