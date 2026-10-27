import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/calculators/calculator_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';

/// Calculators (docs/obdx/features/calculators.md). autoDispose: loaded
/// while a calculator is open. The calculations themselves are run by the
/// screens (they change with every input), not cached here.

/// The bank's local currency (`bankConfiguration`), for the TD and loan
/// calculators.
final calcLocalCurrencyProvider = FutureProvider.autoDispose<String>((ref) async {
  final result = await ref.read(calculatorsRepositoryProvider).fetchLocalCurrency();
  if (result is Success<String> && result.data != null) return result.data!;
  throw CalcLoadError(result is Error<String> ? result.error : null);
});

/// A loan calculator's slider ranges (`defaultRange`), by `var` name.
final calcRangesProvider = FutureProvider.autoDispose.family<Map<String, CalcRange>, CalcKind>((ref, kind) async {
  final result = await ref.read(calculatorsRepositoryProvider).fetchRanges(kind);
  if (result is Success<Map<String, CalcRange>> && result.data != null) return result.data!;
  throw CalcLoadError(result is Error<Map<String, CalcRange>> ? result.error : null);
});

/// Forex currency pairs (`forex/currencyPairs`).
final forexPairsProvider = FutureProvider.autoDispose<ForexPairs>((ref) async {
  final result = await ref.read(calculatorsRepositoryProvider).fetchForexPairs();
  if (result is Success<ForexPairs> && result.data != null) return result.data!;
  throw CalcLoadError(result is Error<ForexPairs> ? result.error : null);
});

/// Load failure; [message] is OBDX's text when the server sent one.
class CalcLoadError implements Exception {
  const CalcLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'CalcLoadError';
}
