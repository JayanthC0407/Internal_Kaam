import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_bill.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_search.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';

/// View Export Bill (Trade Finance ▸ Letter of Credit ▸ Export Letter of
/// Credit ▸ View Bills — manual ch. 14). See [CorpExportBill] for where the
/// request and response names come from.

class ExportBillSearchState {
  const ExportBillSearchState({
    this.criteria = ExportBillSearch.initial,
    this.items = const [],
    this.isLoading = false,
    this.loaded = false,
    this.errorMessage,
  });

  final ExportBillSearch criteria;
  final List<CorpExportBill> items;
  final bool isLoading;
  final bool loaded;
  final String? errorMessage;
}

class ExportBillSearchNotifier extends StateNotifier<ExportBillSearchState> {
  ExportBillSearchNotifier(this._ref) : super(const ExportBillSearchState());

  final Ref _ref;
  int _request = 0;

  Future<void> ensureLoaded() =>
      state.loaded || state.isLoading ? Future.value() : refresh();

  Future<void> search(ExportBillSearch criteria) {
    state = ExportBillSearchState(criteria: criteria, items: state.items);
    return refresh();
  }

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    final request = ++_request;
    final criteria = state.criteria;
    state = ExportBillSearchState(
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
    if (_isInvalidParty(result)) {
      await _ref.read(corpProfileProvider.notifier).refresh();
      if (stale()) return;
      result = await _fetch(criteria);
    }
    if (stale()) return;

    if (result is Success<List<CorpExportBill>>) {
      state = ExportBillSearchState(
        criteria: criteria,
        items: result.data ?? const [],
        loaded: true,
      );
      return;
    }
    final message = await lcFailureMessage(
      result,
      fallback: 'Could not load your export bills.',
    );
    if (stale()) return;
    state = ExportBillSearchState(
      criteria: criteria,
      items: state.items,
      loaded: true,
      errorMessage: message,
    );
  }

  Future<ResponseHandler<List<CorpExportBill>>> _fetch(
    ExportBillSearch criteria,
  ) {
    return _ref.read(corpTradeFinanceRepositoryProvider).searchExportBills(
          criteria.toQuery(partyId: currentLcParty(_ref).value),
        );
  }

  /// The current search as a [format] file.
  Future<({List<int>? bytes, String fileName, String? error})> download(
    TfListFormat format,
  ) async {
    final now = DateTime.now();
    final fileName = 'export-bills-'
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.${format.mediaFormat}';
    final result =
        await _ref.read(corpTradeFinanceRepositoryProvider).downloadExportBills(
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

final corpExportBillSearchProvider = StateNotifierProvider.autoDispose<
    ExportBillSearchNotifier, ExportBillSearchState>(
  (ref) => ExportBillSearchNotifier(ref),
);

Future<Never> _fail(ResponseHandler<dynamic> result, String fallback) async {
  throw await lcFailureMessage(result, fallback: fallback) ?? fallback;
}

/// One bill — `GET …/bills/{billReferenceNo}`.
final exportBillDetailProvider =
    FutureProvider.autoDispose.family<CorpExportBill, String>((ref, id) async {
  final result =
      await ref.read(corpTradeFinanceRepositoryProvider).fetchExportBill(id);
  if (result is Success<CorpExportBill> && result.data != null) {
    return result.data!;
  }
  return _fail(result, 'Could not load the bill.');
});

/// The bills drawn under export LC [lcId]: the party's export bills, any
/// status, narrowed to `lcRefNo == lcId` (the web client has no per-LC
/// bills call of its own).
final exportLcBillsProvider = FutureProvider.autoDispose
    .family<List<CorpExportBill>, String>((ref, lcId) async {
  final result =
      await ref.read(corpTradeFinanceRepositoryProvider).searchExportBills(
            ExportBillSearch.none.toQuery(partyId: currentLcParty(ref).value),
          );
  if (result is Success<List<CorpExportBill>>) {
    return [
      for (final b in result.data ?? const <CorpExportBill>[])
        if (b.lcRefNo == lcId) b,
    ];
  }
  return _fail(result, 'Could not load the bills.');
});
