import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_trade_finance_repository.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';

// Data behind the View LC tabs. Each provider loads only when its tab is
// first opened (as the web does — `view_LC_details.har`, H4) and is
// dropped when the screen closes.

/// A tab load failed; [message] is ready to show.
class LcLoadException implements Exception {
  const LcLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<T> _load<T>(
  Ref ref,
  Future<ResponseHandler<T>> Function(CorpTradeFinanceRepository repo) call, {
  required String fallback,
  required T empty,
}) async {
  final result = await call(ref.read(corpTradeFinanceRepositoryProvider));
  if (result is Success<T>) return result.data ?? empty;
  final message = await lcFailureMessage(result, fallback: fallback);
  throw LcLoadException(message ?? fallback);
}

/// Amendments tab — H4 #49.
final corpLcAmendmentHistoryProvider = FutureProvider.autoDispose
    .family<List<CorpLcAmendment>, String>(
  (ref, lcId) => _load(
    ref,
    (repo) => repo.fetchLcAmendments(lcId),
    fallback: 'Could not load the amendments.',
    empty: const [],
  ),
);

/// Bills tab — H4 #51. Keyed by LC id and type (bill type IMPORT / EXPORT).
final corpLcBillsProvider = FutureProvider.autoDispose
    .family<List<LcBill>, (String, LcType)>(
  (ref, key) => _load(
    ref,
    (repo) => repo.fetchBills(key.$1, key.$2),
    fallback: 'Could not load the bills.',
    empty: const [],
  ),
);

/// Bills tab, shipping guarantees — H4 #53.
final corpLcShippingGuaranteesProvider = FutureProvider.autoDispose
    .family<List<LcShippingGuarantee>, String>(
  (ref, lcId) => _load(
    ref,
    (repo) => repo.fetchShippingGuarantees(lcId),
    fallback: 'Could not load the shipping guarantees.',
    empty: const [],
  ),
);

/// Charges tab — H4 #56.
final corpLcBookedChargesProvider =
    FutureProvider.autoDispose.family<List<LcCharge>, String>(
  (ref, lcId) => _load(
    ref,
    (repo) => repo.fetchLcCharges(lcId),
    fallback: 'Could not load the charges.',
    empty: const [],
  ),
);

/// Branch id → name — H4 #26.
final corpLcBranchNamesProvider =
    FutureProvider.autoDispose<Map<String, String>>(
  (ref) => ref.read(corpTradeFinanceRepositoryProvider).fetchBranchNames(),
);

/// Confirmation parties (ABK / ATB / COB) — H4 #34.
final corpLcConfirmationPartiesProvider =
    FutureProvider.autoDispose<List<TradeCode>>(
  (ref) =>
      ref.read(corpTradeFinanceRepositoryProvider).fetchConfirmationParties(),
);

/// Banks tab — every distinct SWIFT code on the LC resolved through
/// `tradeBicCodes` (H4 #35). [codes] is the comma-joined, sorted code list
/// (a string, so the family key compares by value). Codes that fail or are
/// not found are simply missing from the map.
final corpLcBanksProvider =
    FutureProvider.autoDispose.family<Map<String, TradeBank>, String>(
  (ref, codes) async {
    final repo = ref.read(corpTradeFinanceRepositoryProvider);
    final list = [
      for (final c in codes.split(','))
        if (c.trim().isNotEmpty) c.trim(),
    ];
    final results = await Future.wait(list.map(repo.lookupBic));
    return {
      for (var i = 0; i < list.length; i++)
        if (results[i] case Success<TradeBank?>(:final data?)) list[i]: data,
    };
  },
);

/// Re-fetches every tab of [lcId] (pull-to-refresh / refresh button).
void refreshLcViewTabs(WidgetRef ref, String lcId, LcType lcType) {
  ref.invalidate(corpLcAmendmentHistoryProvider(lcId));
  ref.invalidate(corpLcBillsProvider((lcId, lcType)));
  ref.invalidate(corpLcShippingGuaranteesProvider(lcId));
  ref.invalidate(corpLcBookedChargesProvider(lcId));
  ref.invalidate(corpLcBanksProvider);
}
