import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_trade_finance_api.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_trade_finance_api_constants.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_trade_finance_repository.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';

// ── Wiring ──────────────────────────────────────────────────────────────

final obdxCorpTradeFinanceApiProvider = Provider(
  (ref) => ObdxCorpTradeFinanceApi(ref.watch(obdxDioClientProvider)),
);

final corpTradeFinanceRepositoryProvider = Provider(
  (ref) => CorpTradeFinanceRepository(
    api: ref.watch(obdxCorpTradeFinanceApiProvider),
  ),
);

// ── Shared helpers ──────────────────────────────────────────────────────

/// The applicant party for LC calls: `me/party` first, then the `me`
/// profile's `partyId` (both already loaded by the corporate dashboard).
TfId currentLcParty(Ref ref) {
  final state = ref.read(corpProfileProvider);
  final party = state.party;
  if (party != null && party.id.isNotEmpty) {
    return TfId(value: party.id, displayValue: party.idDisplay);
  }
  final profile = state.profile;
  return TfId(value: profile?.partyId, displayValue: profile?.partyIdDisplay);
}

String? currentLcPartyName(Ref ref) => ref.read(corpProfileProvider).entityName;

/// Maps a failed result to a user message, honouring the session-expiry
/// coordinator (no error text while the app is logging the user out).
Future<String?> lcFailureMessage(
  ResponseHandler<dynamic> result, {
  required String fallback,
}) async {
  if (SessionExpiryCoordinator.instance.isHandling) return null;
  final l10n = await AppLocalizationsHelper.current();
  return result.resolveUserMessage(l10n: l10n, fallback: fallback);
}

/// What the logged-in user may do, from `me/components`.
///
/// While the authorization set is not loaded (empty) everything is
/// allowed — the host still enforces entitlements, and hiding the whole
/// module because a lookup failed would be worse.
class LcPermissions {
  const LcPermissions({
    required this.viewImport,
    required this.viewExport,
    required this.initiate,
    required this.amend,
    this.amendmentAcceptance = true,
    this.initiateTransfer = true,
    this.amendTransfer = true,
  });

  final bool viewImport;
  final bool viewExport;
  final bool initiate;
  final bool amend;
  final bool amendmentAcceptance;
  final bool initiateTransfer;
  final bool amendTransfer;

  bool get anyImport => viewImport || initiate || amend;
  bool get anyExport =>
      viewExport || amendmentAcceptance || initiateTransfer || amendTransfer;
  bool get any => anyImport || anyExport;
}

final lcPermissionsProvider = Provider<LcPermissions>((ref) {
  final authorized = ref.watch(personalizationProvider).authorized;
  bool allowed(String name) => authorized.isEmpty || authorized.contains(name);
  return LcPermissions(
    viewImport: allowed(CorpTradeFinanceApiConst.componentViewImport),
    viewExport: allowed(CorpTradeFinanceApiConst.componentViewExport),
    initiate: allowed(CorpTradeFinanceApiConst.componentInitiate),
    amend: allowed(CorpTradeFinanceApiConst.componentAmend),
    amendmentAcceptance:
        allowed(CorpTradeFinanceApiConst.componentAmendmentAcceptance),
    initiateTransfer:
        allowed(CorpTradeFinanceApiConst.componentInitiateTransfer),
    amendTransfer: allowed(CorpTradeFinanceApiConst.componentAmendTransfer),
  );
});

// ── LC lists (Import / Export / Drafts) ─────────────────────────────────

enum LcListKind {
  importLc('Import LC'),
  exportLc('Export LC'),
  drafts('Drafts'),

  /// Saved LC templates (H1 #37).
  templates('Templates'),
  amendable('Amendable'),

  /// Export LCs that can still be transferred (H2 #202).
  transferable('Transferable LCs'),

  /// Export LCs created by a transfer — the Export list filtered on
  /// `transferredLC` (the dedicated list was not captured).
  transferred('Transferred LCs');

  const LcListKind(this.label);
  final String label;
}

class CorpLcListState {
  const CorpLcListState({
    this.isLoading = false,
    this.items = const [],
    this.errorMessage,
    this.loaded = false,
  });

  final bool isLoading;
  final List<CorpLetterOfCredit> items;
  final String? errorMessage;
  final bool loaded;

  CorpLcListState copyWith({
    bool? isLoading,
    List<CorpLetterOfCredit>? items,
    String? errorMessage,
    bool clearError = false,
    bool? loaded,
  }) {
    return CorpLcListState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loaded: loaded ?? this.loaded,
    );
  }
}

class CorpLcListNotifier extends StateNotifier<CorpLcListState> {
  CorpLcListNotifier(this._ref, this.kind) : super(const CorpLcListState());

  final Ref _ref;
  final LcListKind kind;
  Future<void>? _pending;

  /// Increments on every load, so only the latest response is applied.
  int _request = 0;

  Future<void> ensureLoaded() {
    if (state.loaded && state.errorMessage == null) return Future.value();
    return _pending ??= refresh().whenComplete(() => _pending = null);
  }

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    final request = ++_request;
    state = state.copyWith(isLoading: true, clearError: true);

    bool stale() =>
        !SessionGeneration.isCurrent(generation) ||
        !mounted ||
        request != _request;

    var result = await _fetch();

    // DIGX_LC_042 "Invalid Party": the party id we hold is no longer accepted
    // (seen right after a draft save). Re-read me/party, as the web portal
    // does before every LC screen, and retry once with the fresh id.
    if (_isInvalidParty(result)) {
      await _ref.read(corpProfileProvider.notifier).refresh();
      if (stale()) return;
      result = await _fetch();
    }

    if (stale()) return;

    if (result is Success<List<CorpLetterOfCredit>>) {
      state = CorpLcListState(items: result.data ?? const [], loaded: true);
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not load ${kind.label}.',
    );
    if (stale()) return;
    state = state.copyWith(
      isLoading: false,
      loaded: true,
      errorMessage: message,
      clearError: message == null,
    );
  }

  /// One fetch for this list kind, always using the current party id.
  Future<ResponseHandler<List<CorpLetterOfCredit>>> _fetch() {
    final repo = _ref.read(corpTradeFinanceRepositoryProvider);
    final partyId = currentLcParty(_ref).value;
    return switch (kind) {
      LcListKind.importLc => repo.fetchLetterOfCredits(
          lcType: LcType.importLc,
          partyId: partyId,
        ),
      LcListKind.exportLc => repo.fetchLetterOfCredits(
          lcType: LcType.exportLc,
          partyId: partyId,
        ),
      LcListKind.amendable => repo.fetchLetterOfCredits(
          lcType: LcType.importLc,
          partyId: partyId,
          amendableOnly: true,
        ),
      LcListKind.drafts => repo.fetchDrafts(),
      LcListKind.templates => repo.fetchTemplates(),
      LcListKind.transferable => repo.fetchTransferableLcs(partyId: partyId),
      LcListKind.transferred => repo
          .fetchLetterOfCredits(lcType: LcType.exportLc, partyId: partyId)
          .then((r) => r is Success<List<CorpLetterOfCredit>>
              ? ResponseHandler<List<CorpLetterOfCredit>>.success(
                  [
                    for (final lc in r.data ?? const <CorpLetterOfCredit>[])
                      if (lc.transferredLC) lc,
                  ],
                  code: r.code,
                )
              : r),
    };
  }

  /// Deletes a saved draft (`DELETE /letterofcredits/{id}`). Only valid on
  /// the Drafts list. Removes the row straight away and puts it back if the
  /// host refuses. Returns an error message, or null on success.
  Future<String?> deleteDraft(CorpLetterOfCredit draft) async {
    if (kind != LcListKind.drafts) return 'Only drafts can be deleted.';
    final generation = SessionGeneration.current;
    final before = state.items;
    state = state.copyWith(
      items: [for (final d in before) if (d.id != draft.id) d],
      clearError: true,
    );

    final result = await _ref
        .read(corpTradeFinanceRepositoryProvider)
        .deleteDraft(draft.id);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return null;

    if (result is Success<bool>) return null;
    state = state.copyWith(items: before); // put the row back
    return await lcFailureMessage(
      result,
      fallback: 'Could not delete the draft.',
    );
  }
}

/// True when the host rejected the `partyIds` we sent — DIGX_LC_042
/// "Invalid Party", wrapped in DIGX_LC_075 "Letter Of Credit List failed"
/// (Flutter capture, entries #8/#17).
bool _isInvalidParty(ResponseHandler<dynamic> result) {
  if (result is! Error) return false;
  final code = result.obdxError?.obdxCode?.toUpperCase();
  return code == 'DIGX_LC_042' || code == 'DIGX_LC_075';
}

/// Refreshes a list the user may be looking at after an action changed it.
///
/// Used instead of `invalidate`: the list notifiers load on demand from
/// their page's `initState`, so an invalidated list under an open route
/// would come back empty. A list nobody has opened is left alone.
void refreshLcListIfOpen(Ref ref, LcListKind kind) {
  final provider = corpLcListProvider(kind);
  if (ref.exists(provider)) ref.read(provider.notifier).refresh();
}

final corpLcListProvider = StateNotifierProvider.family<CorpLcListNotifier,
    CorpLcListState, LcListKind>(
  (ref, kind) => CorpLcListNotifier(ref, kind),
);

// ── LC detail ───────────────────────────────────────────────────────────

class CorpLcDetailState {
  const CorpLcDetailState({this.isLoading = true, this.lc, this.errorMessage});

  final bool isLoading;
  final CorpLetterOfCredit? lc;
  final String? errorMessage;
}

class CorpLcDetailNotifier extends StateNotifier<CorpLcDetailState> {
  CorpLcDetailNotifier(this._ref, this.lcId) : super(const CorpLcDetailState()) {
    refresh();
  }

  final Ref _ref;
  final String lcId;

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    state = CorpLcDetailState(lc: state.lc);
    final result = await _ref
        .read(corpTradeFinanceRepositoryProvider)
        .fetchLetterOfCredit(lcId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;

    if (result is Success<CorpLetterOfCredit> && result.data != null) {
      state = CorpLcDetailState(isLoading: false, lc: result.data);
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not load the letter of credit.',
    );
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = CorpLcDetailState(
      isLoading: false,
      lc: state.lc,
      errorMessage: message,
    );
  }
}

final corpLcDetailProvider = StateNotifierProvider.autoDispose
    .family<CorpLcDetailNotifier, CorpLcDetailState, String>(
  (ref, id) => CorpLcDetailNotifier(ref, id),
);

// ── Lookups (products, currencies, goods…) ──────────────────────────────

class CorpLcLookupsState {
  const CorpLcLookupsState({
    this.isLoading = false,
    this.lookups = LcLookups.empty,
    this.errorMessage,
    this.loaded = false,
  });

  final bool isLoading;
  final LcLookups lookups;
  final String? errorMessage;
  final bool loaded;
}

class CorpLcLookupsNotifier extends StateNotifier<CorpLcLookupsState> {
  CorpLcLookupsNotifier(this._ref) : super(const CorpLcLookupsState());

  final Ref _ref;
  Future<void>? _pending;

  Future<void> ensureLoaded() {
    if (state.loaded && state.errorMessage == null) return Future.value();
    return _pending ??= refresh().whenComplete(() => _pending = null);
  }

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    state = CorpLcLookupsState(isLoading: true, lookups: state.lookups);
    final result =
        await _ref.read(corpTradeFinanceRepositoryProvider).fetchLookups();
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;

    if (result is Success<LcLookups> && result.data != null) {
      var lookups = result.data!;
      // Pre-sales returns an empty trade currency enumeration (H1 #42):
      // fall back to the bank's currency master the dashboard loaded.
      if (lookups.currencies.isEmpty) {
        final master = _ref.read(corpProfileProvider).currencies.values;
        lookups = lookups.copyWith(currencies: [
          for (final c in master)
            TradeCode(code: c.code, description: c.description),
        ]);
      }
      state = CorpLcLookupsState(lookups: lookups, loaded: true);
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not load LC products.',
    );
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = CorpLcLookupsState(
      lookups: state.lookups,
      loaded: true,
      errorMessage: message ?? 'Could not load LC products.',
    );
  }
}

final corpLcLookupsProvider =
    StateNotifierProvider<CorpLcLookupsNotifier, CorpLcLookupsState>(
  (ref) => CorpLcLookupsNotifier(ref),
);

// ── Export amendments awaiting acceptance (H2 #157) ─────────────────────

class CorpLcAmendmentListState {
  const CorpLcAmendmentListState({
    this.isLoading = false,
    this.items = const [],
    this.errorMessage,
    this.loaded = false,
  });

  final bool isLoading;
  final List<CorpLcAmendment> items;
  final String? errorMessage;
  final bool loaded;

  CorpLcAmendment? byKey(String key) {
    for (final a in items) {
      if (a.key == key) return a;
    }
    return null;
  }
}

class CorpLcAmendmentListNotifier
    extends StateNotifier<CorpLcAmendmentListState> {
  CorpLcAmendmentListNotifier(this._ref)
      : super(const CorpLcAmendmentListState());

  final Ref _ref;
  Future<void>? _pending;

  Future<void> ensureLoaded() {
    if (state.loaded && state.errorMessage == null) return Future.value();
    return _pending ??= refresh().whenComplete(() => _pending = null);
  }

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    state = CorpLcAmendmentListState(isLoading: true, items: state.items);
        Future<ResponseHandler<List<CorpLcAmendment>>> fetch() => _ref
        .read(corpTradeFinanceRepositoryProvider)
        .fetchExportAmendments(partyId: currentLcParty(_ref).value);

    var result = await fetch();
    if (_isInvalidParty(result)) {
      await _ref.read(corpProfileProvider.notifier).refresh();
      if (!SessionGeneration.isCurrent(generation) || !mounted) return;
      result = await fetch();
    }
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    if (result is Success<List<CorpLcAmendment>>) {
      state = CorpLcAmendmentListState(
        items: result.data ?? const [],
        loaded: true,
      );
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not load LC amendments.',
    );
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = CorpLcAmendmentListState(
      items: state.items,
      loaded: true,
      errorMessage: message,
    );
  }
}

final corpLcExportAmendmentsProvider = StateNotifierProvider<
    CorpLcAmendmentListNotifier, CorpLcAmendmentListState>(
  (ref) => CorpLcAmendmentListNotifier(ref),
);

// ── LC search (Initiate → Copy & Initiate / Back to Back LC) ────────────

enum LcSearchMode { copy, backToBack }

class CorpLcSearchState {
  const CorpLcSearchState({
    required this.criteria,
    this.isLoading = false,
    this.results,
    this.errorMessage,
  });

  final LcSearchCriteria criteria;
  final bool isLoading;

  /// Null until the first search; empty = searched, nothing found.
  final List<CorpLetterOfCredit>? results;
  final String? errorMessage;

  bool get searched => results != null;
}

class CorpLcSearchNotifier extends StateNotifier<CorpLcSearchState> {
  CorpLcSearchNotifier(this._ref, this.mode)
      : super(CorpLcSearchState(criteria: _initial(mode)));

  final Ref _ref;
  final LcSearchMode mode;
  int _request = 0;

  static LcSearchCriteria _initial(LcSearchMode mode) =>
      mode == LcSearchMode.copy
          ? LcSearchCriteria.copy()
          : LcSearchCriteria.backToBack();

  void update(LcSearchCriteria Function(LcSearchCriteria c) change) {
    state = CorpLcSearchState(
      criteria: change(state.criteria),
      results: state.results,
    );
  }

  void clear() => state = CorpLcSearchState(criteria: state.criteria.cleared());

  Future<void> search() async {
    final generation = SessionGeneration.current;
    final request = ++_request;
    state = CorpLcSearchState(
      criteria: state.criteria,
      isLoading: true,
      results: state.results,
    );
    bool stale() =>
        !SessionGeneration.isCurrent(generation) ||
        !mounted ||
        request != _request;

    final repo = _ref.read(corpTradeFinanceRepositoryProvider);
    Future<ResponseHandler<List<CorpLetterOfCredit>>> run() =>
        repo.searchLetterOfCredits(
          state.criteria,
          partyId: currentLcParty(_ref).value,
        );

    var result = await run();
    if (_isInvalidParty(result)) {
      await _ref.read(corpProfileProvider.notifier).refresh();
      if (stale()) return;
      result = await run();
    }
    if (stale()) return;

    if (result is Success<List<CorpLetterOfCredit>>) {
      state = CorpLcSearchState(
        criteria: state.criteria,
        results: result.data ?? const [],
      );
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not search letters of credit.',
    );
    if (stale()) return;
    state = CorpLcSearchState(
      criteria: state.criteria,
      results: const [],
      errorMessage: message,
    );
  }
}

final corpLcSearchProvider = StateNotifierProvider.autoDispose
    .family<CorpLcSearchNotifier, CorpLcSearchState, LcSearchMode>(
  (ref, mode) => CorpLcSearchNotifier(ref, mode),
);
