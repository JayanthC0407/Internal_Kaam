import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/payee/payee_models.dart';
import 'package:ubci_bank/src/core/models/retail/cheque_book_models.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_cheque_book_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/cheque_book_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';

/// Cheque Book Request (docs/obdx/features/cheque-book-request.md). autoDispose.

final obdxChequeBookApiProvider = Provider((ref) => ObdxChequeBookApi(ref.watch(obdxDioClientProvider)));

final chequeBookRepositoryProvider =
    Provider((ref) => ChequeBookRepository(api: ref.watch(obdxChequeBookApiProvider)));

final chequeBookSetupProvider = FutureProvider.autoDispose<ChequeBookSetup>(
  (ref) async => _data(await ref.read(chequeBookRepositoryProvider).fetchSetup()),
);

final chequePartyAddressesProvider = FutureProvider.autoDispose<List<ChequePartyAddress>>(
  (ref) async => _data(await ref.read(chequeBookRepositoryProvider).fetchPartyAddresses()),
);

final chequeAccountAddressProvider = FutureProvider.autoDispose.family<ChequeAddress, String>(
  (ref, accountId) async => _data(await ref.read(chequeBookRepositoryProvider).fetchAccountAddress(accountId)),
);

final chequeCitiesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) async => _data(await ref.read(chequeBookRepositoryProvider).fetchCities()),
);

final chequeBranchesProvider = FutureProvider.autoDispose.family<List<BranchOption>, String>(
  (ref, city) async => _data(await ref.read(chequeBookRepositoryProvider).fetchBranches(city)),
);

final chequeBranchAddressProvider = FutureProvider.autoDispose.family<ChequeAddress, String>(
  (ref, branchCode) async => _data(await ref.read(chequeBookRepositoryProvider).fetchBranchAddress(branchCode)),
);

T _data<T>(ResponseHandler<T> result) {
  if (result is Success<T> && result.data != null) return result.data as T;
  throw ChequeBookLoadError(result is Error<T> ? result.error : null);
}

/// Load failure; [message] is OBDX's text when the server sent one.
class ChequeBookLoadError implements Exception {
  const ChequeBookLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'ChequeBookLoadError';
}
