import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/retail/sweep_in_models.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_sweep_in_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/sweep_in_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';

/// Sweep-In (docs/obdx/features/sweep-in.md). autoDispose.

final obdxSweepInApiProvider = Provider((ref) => ObdxSweepInApi(ref.watch(obdxDioClientProvider)));

final sweepInRepositoryProvider = Provider((ref) => SweepInRepository(api: ref.watch(obdxSweepInApiProvider)));

final sweepPickerAccountsProvider = FutureProvider.autoDispose<List<SweepAccount>>(
  (ref) async => _data(await ref.read(sweepInRepositoryProvider).fetchPickerAccounts()),
);

/// Keyed by (account id, Linked Account Type).
final sweepListsProvider = FutureProvider.autoDispose.family<SweepLists, (String, SweepType)>(
  (ref, key) async => _data(await ref.read(sweepInRepositoryProvider).fetchLists(key.$1, key.$2)),
);

T _data<T>(ResponseHandler<T> result) {
  if (result is Success<T> && result.data != null) return result.data as T;
  throw SweepInLoadError(result is Error<T> ? result.error : null);
}

/// Load failure; [message] is OBDX's text when the server sent one.
class SweepInLoadError implements Exception {
  const SweepInLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'SweepInLoadError';
}
