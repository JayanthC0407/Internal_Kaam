import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_search.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_bank_guarantee_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_bank_guarantee_repository.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_export_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';

/// Trade Finance ▸ Bank Guarantee ▸ Inward Bank Guarantee/Stand By LC.
///
/// Conventional and Islamic options share every provider here; the
/// [BgCategory] in each key is the only difference (`categoryType`).

// ── Wiring ──────────────────────────────────────────────────────────────

final obdxCorpBankGuaranteeApiProvider = Provider(
  (ref) => ObdxCorpBankGuaranteeApi(ref.watch(obdxDioClientProvider)),
);

final corpBankGuaranteeRepositoryProvider = Provider(
  (ref) => CorpBankGuaranteeRepository(
    api: ref.watch(obdxCorpBankGuaranteeApiProvider),
  ),
);

// ── Lookups ─────────────────────────────────────────────────────────────

/// Parties, currencies and demand indicators; with `true`, also the bank's
/// business date (the Lodge Claim date limits). Never fails — a lookup
/// that fails leaves its part empty.
final bgLookupsProvider =
    FutureProvider.autoDispose.family<BgLookups, bool>((ref, withBranchDate) {
  return ref
      .read(corpBankGuaranteeRepositoryProvider)
      .fetchLookups(withBranchDate: withBranchDate);
});

// ── Search (View list, Lodge Claim) ─────────────────────────────────────

enum BgListMode {
  /// View Bank Guarantee/Kafalah — loads on open (BG #44 / #51).
  view,

  /// Initiate Lodge Claim — `isClaimable=true`, loads on Search (BG #76 /
  /// #84), as the web form does.
  claimable,
}

typedef BgListKey = ({BgCategory category, BgListMode mode});

class BgSearchState {
  const BgSearchState({
    this.criteria = BgSearch.none,
    this.items = const [],
    this.isLoading = false,
    this.loaded = false,
    this.errorMessage,
  });

  final BgSearch criteria;
  final List<CorpBankGuarantee> items;
  final bool isLoading;

  /// A search has completed at least once.
  final bool loaded;
  final String? errorMessage;
}

class BgSearchNotifier extends StateNotifier<BgSearchState> {
  BgSearchNotifier(this._ref, this.key) : super(const BgSearchState());

  final Ref _ref;
  final BgListKey key;
  int _request = 0;

  bool get _claimable => key.mode == BgListMode.claimable;

  Future<void> ensureLoaded() =>
      state.loaded || state.isLoading ? Future.value() : refresh();

  /// Runs [criteria] and keeps it for refreshes and the download.
  Future<void> search(BgSearch criteria) {
    state = BgSearchState(
      criteria: criteria,
      items: state.items,
      loaded: state.loaded,
    );
    return refresh();
  }

  /// Back to the empty form (Lodge Claim's Reset).
  void reset() {
    _request++;
    state = const BgSearchState();
  }

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    final request = ++_request;
    final criteria = state.criteria;
    state = BgSearchState(
      criteria: criteria,
      items: state.items,
      isLoading: true,
      loaded: state.loaded,
    );

    final result = await _ref
        .read(corpBankGuaranteeRepositoryProvider)
        .searchGuarantees(
          criteria,
          category: key.category,
          claimableOnly: _claimable,
        );
    if (!SessionGeneration.isCurrent(generation) ||
        !mounted ||
        request != _request) {
      return;
    }

    if (result is Success<List<CorpBankGuarantee>>) {
      state = BgSearchState(
        criteria: criteria,
        items: result.data ?? const [],
        loaded: true,
      );
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not load your ${key.category.lowerNoun}s.',
    );
    if (!mounted || request != _request) return;
    state = BgSearchState(
      criteria: criteria,
      loaded: true,
      errorMessage: message,
    );
  }

  /// The current search as a [format] file. On success returns the bytes
  /// and a file name; otherwise the message to show.
  Future<({List<int>? bytes, String fileName, String? error})> download(
    TfListFormat format,
  ) async {
    final now = DateTime.now();
    final stem = _claimable ? 'claimable' : 'inward';
    final fileName = '$stem-${key.category.lowerNoun}s-'
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.${format.mediaFormat}';
    final result = await _ref
        .read(corpBankGuaranteeRepositoryProvider)
        .downloadGuarantees(
          state.criteria,
          category: key.category,
          media: format.media,
          mediaFormat: format.mediaFormat,
          claimableOnly: _claimable,
        );
    if (result is Success<List<int>> && result.data != null) {
      return (bytes: result.data, fileName: fileName, error: null);
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not download the list.',
    );
    return (
      bytes: null,
      fileName: fileName,
      error: message ?? 'Could not download the list.',
    );
  }
}

/// Kept while the Trade Finance page is open, so filters survive opening
/// a guarantee and coming back.
final corpBgSearchProvider = StateNotifierProvider.autoDispose
    .family<BgSearchNotifier, BgSearchState, BgListKey>(
  (ref, key) => BgSearchNotifier(ref, key),
);

// ── Detail ──────────────────────────────────────────────────────────────

typedef BgDetailKey = ({String id, BgCategory category});

/// One guarantee in full (`bankguarantees/{id}`). Fails with the message to
/// show.
final corpBgDetailProvider = FutureProvider.autoDispose
    .family<CorpBankGuarantee, BgDetailKey>((ref, key) async {
  final result = await ref
      .read(corpBankGuaranteeRepositoryProvider)
      .fetchGuarantee(key.id, category: key.category);
  if (result is Success<CorpBankGuarantee> && result.data != null) {
    return result.data!;
  }
  final fallback = 'Could not load this ${key.category.lowerNoun}.';
  throw await lcFailureMessage(result, fallback: fallback) ?? fallback;
});

// ── Amendments awaiting acceptance ──────────────────────────────────────

class BgAmendmentsState {
  const BgAmendmentsState({
    this.items = const [],
    this.isLoading = false,
    this.loaded = false,
    this.errorMessage,
    this.partyId,
  });

  final List<CorpBgAmendment> items;
  final bool isLoading;
  final bool loaded;
  final String? errorMessage;

  /// The party picked in "Select party"; null for all.
  final String? partyId;
}

class BgAmendmentsNotifier extends StateNotifier<BgAmendmentsState> {
  BgAmendmentsNotifier(this._ref, this.category)
      : super(const BgAmendmentsState());

  final Ref _ref;
  final BgCategory category;
  int _request = 0;

  Future<void> setParty(String? partyId) {
    state = BgAmendmentsState(items: state.items, partyId: partyId);
    return refresh();
  }

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    final request = ++_request;
    final partyId = state.partyId;
    state = BgAmendmentsState(
      items: state.items,
      isLoading: true,
      loaded: state.loaded,
      partyId: partyId,
    );
    final result = await _ref
        .read(corpBankGuaranteeRepositoryProvider)
        .fetchAmendments(category: category, partyId: partyId);
    if (!SessionGeneration.isCurrent(generation) ||
        !mounted ||
        request != _request) {
      return;
    }
    if (result is Success<List<CorpBgAmendment>>) {
      state = BgAmendmentsState(
        items: result.data ?? const [],
        loaded: true,
        partyId: partyId,
      );
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not load the pending amendments.',
    );
    if (!mounted || request != _request) return;
    state = BgAmendmentsState(
      loaded: true,
      errorMessage: message,
      partyId: partyId,
    );
  }
}

final corpBgAmendmentsProvider = StateNotifierProvider.autoDispose
    .family<BgAmendmentsNotifier, BgAmendmentsState, BgCategory>(
  (ref, category) => BgAmendmentsNotifier(ref, category),
);

/// One amendment in full, next to the guarantee as it stands. Either
/// half may be missing (null) when its call fails; [warning] then says so.
class BgAmendmentView {
  const BgAmendmentView({
    required this.amendment,
    this.guarantee,
    this.warning,
  });

  final CorpBgAmendment amendment;
  final CorpBankGuarantee? guarantee;
  final String? warning;
}

final corpBgAmendmentViewProvider = FutureProvider.autoDispose
    .family<BgAmendmentView, CorpBgAmendment>((ref, listed) async {
  final repo = ref.read(corpBankGuaranteeRepositoryProvider);
  final results = await Future.wait([
    repo.fetchAmendment(listed),
    repo.fetchGuarantee(listed.bgId, category: listed.category),
  ]);
  final amendment = results[0] is Success<CorpBgAmendment>
      ? (results[0] as Success<CorpBgAmendment>).data
      : null;
  final guarantee = results[1] is Success<CorpBankGuarantee>
      ? (results[1] as Success<CorpBankGuarantee>).data
      : null;
  return BgAmendmentView(
    amendment: amendment ?? listed,
    guarantee: guarantee,
    warning: amendment == null || guarantee == null
        ? 'Some details could not be loaded. What the bank sent is shown.'
        : null,
  );
});

// ── Approve / reject (one or more amendments) ───────────────────────────

/// What the review screen submits: the amendments ticked on the
/// acceptance list, the decision and the special instructions.
class BgAcceptanceRequest {
  const BgAcceptanceRequest({
    required this.category,
    required this.amendments,
    required this.accept,
    required this.instructions,
  });

  final BgCategory category;
  final List<CorpBgAmendment> amendments;
  final bool accept;
  final String instructions;
}

/// The outcome for one amendment: sent ([outcome]) or refused ([error]).
class BgResponseResult {
  const BgResponseResult.sent(LcSubmitted this.outcome) : error = null;
  const BgResponseResult.failed(String this.error) : outcome = null;

  final LcSubmitted? outcome;
  final String? error;

  bool get isSent => outcome != null;
}

class BgAcceptanceState {
  const BgAcceptanceState({
    this.isSubmitting = false,
    this.results = const {},
    this.challenge,
    this.otpError,
    this.done = false,
  });

  final bool isSubmitting;

  /// By [CorpBgAmendment.key].
  final Map<String, BgResponseResult> results;
  final ObdxChallenge? challenge;
  final String? otpError;

  /// Every amendment has a result.
  final bool done;

  bool get started => results.isNotEmpty || isSubmitting || challenge != null;

  BgAcceptanceState copyWith({
    bool? isSubmitting,
    Map<String, BgResponseResult>? results,
    ObdxChallenge? challenge,
    bool clearChallenge = false,
    String? otpError,
    bool clearOtpError = false,
    bool? done,
  }) {
    return BgAcceptanceState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      results: results ?? this.results,
      challenge: clearChallenge ? null : (challenge ?? this.challenge),
      otpError: (clearChallenge || clearOtpError)
          ? null
          : (otpError ?? this.otpError),
      done: done ?? this.done,
    );
  }
}

/// Sends the decision for each amendment in turn. When the host asks for
/// an OTP the run pauses on that amendment; [submitOtp] resumes it.
class BgAcceptanceNotifier extends StateNotifier<BgAcceptanceState> {
  BgAcceptanceNotifier(this._ref, this.request)
      : super(const BgAcceptanceState());

  final Ref _ref;
  final BgAcceptanceRequest request;
  int _index = 0;

  Future<void> submit() => _process();

  Future<void> submitOtp(String otp) => _process(otp: otp);

  /// Verification abandoned: the paused amendment and the ones after it
  /// are reported as not sent.
  void cancelOtp() {
    if (state.challenge == null) return;
    final results = {...state.results};
    for (var i = _index; i < request.amendments.length; i++) {
      results[request.amendments[i].key] = const BgResponseResult.failed(
        'Not sent — verification was cancelled.',
      );
    }
    _index = request.amendments.length;
    state = state.copyWith(
      isSubmitting: false,
      clearChallenge: true,
      results: results,
      done: true,
    );
    _afterRun();
  }

  Future<void> _process({String? otp}) async {
    final generation = SessionGeneration.current;
    final repo = _ref.read(corpBankGuaranteeRepositoryProvider);
    var code = otp;
    state = state.copyWith(isSubmitting: true, clearOtpError: true);

    while (_index < request.amendments.length) {
      final amendment = request.amendments[_index];
      final result = await repo.respondToAmendment(
        amendment,
        accept: request.accept,
        instructions: request.instructions,
        challenge: code == null ? null : state.challenge,
        otp: code,
      );
      if (!SessionGeneration.isCurrent(generation) || !mounted) return;

      if (result is Success<LcSubmitOutcome>) {
        final data = result.data;
        if (data is LcAwaitingOtp) {
          state = state.copyWith(
            isSubmitting: false,
            challenge: data.challenge,
            otpError: code == null ? null : 'Incorrect code. Please try again.',
            clearOtpError: code == null,
          );
          return;
        }
        if (data is LcSubmitted) {
          state = state.copyWith(
            results: {
              ...state.results,
              amendment.key: BgResponseResult.sent(data),
            },
            clearChallenge: true,
          );
          _index++;
          code = null;
          continue;
        }
      }

      final message = await lcFailureMessage(
            result,
            fallback: 'The bank did not accept this response.',
          ) ??
          'The bank did not accept this response.';
      if (!mounted) return;
      if (code != null && state.challenge != null) {
        // A wrong or expired code: stay on this amendment.
        state = state.copyWith(isSubmitting: false, otpError: message);
        return;
      }
      state = state.copyWith(
        results: {
          ...state.results,
          amendment.key: BgResponseResult.failed(message),
        },
        clearChallenge: true,
      );
      _index++;
      code = null;
    }

    state = state.copyWith(isSubmitting: false, clearChallenge: true, done: true);
    _afterRun();
  }

  void _afterRun() {
    final list = corpBgAmendmentsProvider(request.category);
    if (_ref.exists(list)) _ref.read(list.notifier).refresh();
  }
}

/// Keyed by the request instance the review route carries.
final corpBgAcceptanceProvider = StateNotifierProvider.autoDispose
    .family<BgAcceptanceNotifier, BgAcceptanceState, BgAcceptanceRequest>(
  (ref, request) => BgAcceptanceNotifier(ref, request),
);

// ── Lodge claim ─────────────────────────────────────────────────────────

class BgClaimNotifier extends LcActionNotifier<BgClaimDraft> {
  BgClaimNotifier(Ref ref, this.guarantee)
      : super(
          ref,
          LcActionState<BgClaimDraft>(
            isLoading: true,
            data: BgClaimDraft(guarantee: guarantee),
          ),
        ) {
    _loadDetail();
  }

  /// The row picked on the Lodge Claim list.
  final CorpBankGuarantee guarantee;

  /// The detail adds what the list row lacks (expiry type, demand
  /// indicator). If it fails, the claim goes ahead from the list row.
  Future<void> _loadDetail() async {
    final generation = SessionGeneration.current;
    final result = await ref
        .read(corpBankGuaranteeRepositoryProvider)
        .fetchGuarantee(guarantee.id, category: guarantee.category);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    final current = state.data ?? BgClaimDraft(guarantee: guarantee);
    final detail =
        result is Success<CorpBankGuarantee> ? result.data : null;
    state = LcActionState<BgClaimDraft>(
      data: detail == null
          ? current
          : BgClaimDraft(
              guarantee: detail,
              amount: current.amount,
              demandType: current.demandType,
              extendTo: current.extendTo,
              description: current.description,
            ),
    );
  }

  void update(BgClaimDraft Function(BgClaimDraft draft) change) {
    final draft = state.data;
    if (draft == null) return;
    state = state.copyWith(data: change(draft), clearError: true);
  }

  /// Claims under an indicator of "no partial demands" must be for the
  /// full outstanding amount (SWIFT 48D `NMPT` / `NPRT`).
  bool get fullAmountOnly {
    final code = state.data?.guarantee.demandIndicator?.toUpperCase();
    return code == 'NMPT' || code == 'NPRT';
  }

  /// What is wrong with the draft, or null when it can be sent.
  String? validate() {
    final draft = state.data;
    if (draft == null) return 'The ${guarantee.category.lowerNoun} is still loading.';
    final amount = draft.amount;
    final outstanding = draft.guarantee.outstandingAmount?.amount;
    if (amount == null || amount <= 0) return 'Enter the amount you are claiming.';
    if (outstanding != null && amount > outstanding) {
      return 'The claim is more than the outstanding amount.';
    }
    if (fullAmountOnly && outstanding != null && amount != outstanding) {
      return 'This ${guarantee.category.lowerNoun} does not allow partial '
          'claims. Claim the full outstanding amount.';
    }
    if (draft.demandType == BgDemandType.extendOrPay) {
      final extendTo = draft.extendTo;
      if (extendTo == null) return 'Choose the new expiry date you are asking for.';
      final expiry = draft.guarantee.expiryDate;
      if (expiry != null && !extendTo.isAfter(expiry)) {
        return 'The new expiry date must be after the current one.';
      }
    }
    if ((draft.description?.trim() ?? '').isEmpty) {
      return 'Describe the claim — the bank passes this to the issuer.';
    }
    return null;
  }

  Future<void> submit() {
    final error = validate();
    if (error != null) {
      state = state.copyWith(errorMessage: error);
      return Future.value();
    }
    return run();
  }

  Future<void> submitOtp(String otp) => run(otp: otp);

  @override
  Future<ResponseHandler<LcSubmitOutcome>> send({
    ObdxChallenge? challenge,
    String? otp,
  }) {
    return ref.read(corpBankGuaranteeRepositoryProvider).lodgeClaim(
          state.data!,
          challenge: challenge,
          otp: otp,
        );
  }

  @override
  void onSubmitted() {
    final list = corpBgSearchProvider(
      (category: guarantee.category, mode: BgListMode.claimable),
    );
    if (ref.exists(list)) ref.read(list.notifier).refresh();
  }

  @override
  String get failureFallback => 'Could not lodge the claim.';
}

/// Keyed by the guarantee instance the claim route carries.
final corpBgClaimProvider = StateNotifierProvider.autoDispose
    .family<BgClaimNotifier, LcActionState<BgClaimDraft>, CorpBankGuarantee>(
  (ref, guarantee) => BgClaimNotifier(ref, guarantee),
);
