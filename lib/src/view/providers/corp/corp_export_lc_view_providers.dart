import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_search.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';

/// View Export LC (Trade Finance ▸ Letter of Credit ▸ Export Letter of
/// Credit ▸ View Letter of Credit — manual ch. 11).

// ── Search ──────────────────────────────────────────────────────────────

class ExportLcSearchState {
  const ExportLcSearchState({
    this.criteria = ExportLcSearch.none,
    this.items = const [],
    this.isLoading = false,
    this.loaded = false,
    this.errorMessage,
  });

  final ExportLcSearch criteria;

  /// The host's results with [ExportLcSearch.matches] applied.
  final List<CorpLetterOfCredit> items;
  final bool isLoading;
  final bool loaded;
  final String? errorMessage;
}

class ExportLcSearchNotifier extends StateNotifier<ExportLcSearchState> {
  ExportLcSearchNotifier(this._ref) : super(const ExportLcSearchState());

  final Ref _ref;
  int _request = 0;

  Future<void> ensureLoaded() =>
      state.loaded || state.isLoading ? Future.value() : refresh();

  /// Runs [criteria] and keeps it for refreshes and the download.
  Future<void> search(ExportLcSearch criteria) {
    state = ExportLcSearchState(criteria: criteria, items: state.items);
    return refresh();
  }

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    final request = ++_request;
    final criteria = state.criteria;
    state = ExportLcSearchState(
      criteria: criteria,
      items: state.items,
      isLoading: true,
      loaded: state.loaded,
    );
    bool stale() =>
        !SessionGeneration.isCurrent(generation) ||
        !mounted ||
        request != _request;

    var result = await _fetch(criteria);
    // The host rejected the party id we hold (DIGX_LC_042 / _075): re-read
    // the party, as the other LC lists do, and try once more.
    if (_isInvalidParty(result)) {
      await _ref.read(corpProfileProvider.notifier).refresh();
      if (stale()) return;
      result = await _fetch(criteria);
    }
    if (stale()) return;

    if (result is Success<List<CorpLetterOfCredit>>) {
      state = ExportLcSearchState(
        criteria: criteria,
        items: [
          for (final lc in result.data ?? const <CorpLetterOfCredit>[])
            if (criteria.matches(lc)) lc,
        ],
        loaded: true,
      );
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not load your export letters of credit.',
    );
    if (stale()) return;
    state = ExportLcSearchState(
      criteria: criteria,
      items: state.items,
      loaded: true,
      errorMessage: message,
    );
  }

  Future<ResponseHandler<List<CorpLetterOfCredit>>> _fetch(
    ExportLcSearch criteria,
  ) {
    return _ref
        .read(corpTradeFinanceRepositoryProvider)
        .searchExportLetterOfCredits(
          criteria.toQuery(partyId: currentLcParty(_ref).value),
        );
  }

  /// The current search as a [format] file. On success returns the bytes
  /// and a file name; otherwise the message to show.
  Future<({List<int>? bytes, String fileName, String? error})> download(
    TfListFormat format,
  ) async {
    final now = DateTime.now();
    final fileName = 'export-letters-of-credit-'
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.${format.mediaFormat}';
    final result = await _ref
        .read(corpTradeFinanceRepositoryProvider)
        .downloadLetterOfCredits(
          state.criteria.toQuery(partyId: currentLcParty(_ref).value),
          media: format.media,
          mediaFormat: format.mediaFormat,
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

  static bool _isInvalidParty(ResponseHandler<dynamic> result) {
    if (result is! Error) return false;
    final code = result.obdxError?.obdxCode?.toUpperCase();
    return code == 'DIGX_LC_042' || code == 'DIGX_LC_075';
  }
}

/// Kept while the Trade Finance page is open, so filters survive opening
/// an LC and coming back; dropped with it, so nothing outlives the session.
final corpExportLcSearchProvider = StateNotifierProvider.autoDispose<
    ExportLcSearchNotifier, ExportLcSearchState>(
  (ref) => ExportLcSearchNotifier(ref),
);

// ── Detail: pending amendments, bank names ──────────────────────────────

/// The amendments to [lcId] awaiting the user's acceptance — the captured
/// `letterofcredits/amendments?type=EXPORT` list, narrowed to this LC.
/// (No capture lists an LC's full amendment history.)
final exportLcPendingAmendmentsProvider = FutureProvider.autoDispose
    .family<List<CorpLcAmendment>, String>((ref, lcId) async {
  final result = await ref
      .read(corpTradeFinanceRepositoryProvider)
      .fetchExportAmendments(partyId: currentLcParty(ref).value);
  if (result is Success<List<CorpLcAmendment>>) {
    return [
      for (final a in result.data ?? const <CorpLcAmendment>[])
        if (a.lcId == lcId) a,
    ];
  }
  throw await lcFailureMessage(
        result,
        fallback: 'Could not load the amendments.',
      ) ??
      'Could not load the amendments.';
});

/// A bank by SWIFT code (`tradeBicCodes`), for the Banks tab; null when
/// the host does not know the code or the lookup fails — the tab then
/// shows the code alone.
final tradeBankByCodeProvider =
    FutureProvider.autoDispose.family<TradeBank?, String>((ref, code) async {
  final result =
      await ref.read(corpTradeFinanceRepositoryProvider).lookupBic(code);
  return result is Success<TradeBank?> ? result.data : null;
});
