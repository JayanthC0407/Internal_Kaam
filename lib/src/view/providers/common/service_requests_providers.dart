import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/service_requests/service_request_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';

/// Service Requests. autoDispose: loaded while the module is open, dropped
/// afterwards and on logout.

T _unwrap<T>(ResponseHandler<T> result) {
  if (result is Success<T> && result.data != null) return result.data as T;
  throw ServiceRequestsLoadError(result is Error<T> ? result.error : null);
}

/// Track filter: products.
final srProductsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) async => _unwrap(await ref.read(serviceRequestsRepositoryProvider).fetchProducts()),
);

/// A product's categories (Track filter, and names on Raise).
final srCategoriesProvider = FutureProvider.autoDispose.family<List<SrCategory>, String>(
  (ref, product) async => _unwrap(await ref.read(serviceRequestsRepositoryProvider).fetchCategories(product)),
);

/// An enumeration by name: `srStatus`, `srRequestType`, `gender`,
/// `salutation`, `country`, `country/{code}/state`.
final srEnumerationProvider = FutureProvider.autoDispose.family<List<SrOption>, String>(
  (ref, name) async => _unwrap(await ref.read(serviceRequestsRepositoryProvider).fetchEnumeration(name)),
);

/// Track list for a filter; only read once the user presses Apply.
final srRequestsProvider = FutureProvider.autoDispose.family<List<ServiceRequestSummary>, SrFilter>(
  (ref, filter) async => _unwrap(await ref.read(serviceRequestsRepositoryProvider).fetchRequests(filter)),
);

final srRequestProvider = FutureProvider.autoDispose.family<ServiceRequestDetail, String>(
  (ref, id) async => _unwrap(await ref.read(serviceRequestsRepositoryProvider).fetchRequest(id)),
);

/// Everything the user may raise.
final srDefinitionsProvider = FutureProvider.autoDispose<List<SrDefinition>>(
  (ref) async => _unwrap(await ref.read(serviceRequestsRepositoryProvider).fetchDefinitions()),
);

/// One definition with its form.
final srDefinitionProvider = FutureProvider.autoDispose.family<SrDefinition, String>(
  (ref, id) async => _unwrap(await ref.read(serviceRequestsRepositoryProvider).fetchDefinition(id)),
);

/// PDAN / PDAD accounts.
final srAccountsProvider = FutureProvider.autoDispose<List<SrAccount>>(
  (ref) async => _unwrap(await ref.read(serviceRequestsRepositoryProvider).fetchAccounts()),
);

/// PDAD debit cards of one account.
final srDebitCardsProvider = FutureProvider.autoDispose.family<List<SrOption>, String>(
  (ref, account) async => _unwrap(await ref.read(serviceRequestsRepositoryProvider).fetchDebitCards(account)),
);

/// Load failure; [message] is OBDX's text when the server sent one.
class ServiceRequestsLoadError implements Exception {
  const ServiceRequestsLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'ServiceRequestsLoadError';
}
