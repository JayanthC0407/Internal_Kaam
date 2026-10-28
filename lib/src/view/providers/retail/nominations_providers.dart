import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/retail/certificate_models.dart';
import 'package:ubci_bank/src/core/models/retail/nomination_models.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_nominations_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/nominations_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';

/// Nominations (docs/obdx/features/nominations.md). autoDispose.

final obdxNominationsApiProvider = Provider((ref) => ObdxNominationsApi(ref.watch(obdxDioClientProvider)));

final nominationsRepositoryProvider =
    Provider((ref) => NominationsRepository(api: ref.watch(obdxNominationsApiProvider)));

final nominationPickerAccountsProvider = FutureProvider.autoDispose
    .family<List<CertificateAccount>, NominationCategory>((ref, c) async {
  final result = await ref.read(nominationsRepositoryProvider).fetchPickerAccounts(c);
  if (result is Success<List<CertificateAccount>> && result.data != null) return result.data!;
  throw NominationsLoadError(result is Error<List<CertificateAccount>> ? result.error : null);
});

final nominationRowsProvider =
    FutureProvider.autoDispose.family<List<NominationRow>, NominationCategory>((ref, c) async {
  final result = await ref.read(nominationsRepositoryProvider).fetchRows(c);
  if (result is Success<List<NominationRow>> && result.data != null) return result.data!;
  throw NominationsLoadError(result is Error<List<NominationRow>> ? result.error : null);
});

/// View Nominee: the nominee, and the relationship / country names (best
/// effort — without them the codes are shown).
final nomineeDetailsProvider = FutureProvider.autoDispose.family<NomineeDetails, String>((ref, accountId) async {
  final repository = ref.read(nominationsRepositoryProvider);
  final (nominee, relations, countries) = await (
    repository.fetchNominee(accountId),
    repository.fetchRelations(),
    repository.fetchCountries(),
  ).wait;
  if (nominee is! Success<Nominee> || nominee.data == null) {
    throw NominationsLoadError(nominee is Error<Nominee> ? nominee.error : null);
  }
  return NomineeDetails(
    nominee: nominee.data!,
    relations: relations is Success<Map<String, String>> ? relations.data ?? const {} : const {},
    countries: countries is Success<Map<String, String>> ? countries.data ?? const {} : const {},
  );
});

class NomineeDetails {
  const NomineeDetails({required this.nominee, this.relations = const {}, this.countries = const {}});

  final Nominee nominee;
  final Map<String, String> relations;
  final Map<String, String> countries;
}

/// Load failure; [message] is OBDX's text when the server sent one.
class NominationsLoadError implements Exception {
  const NominationsLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'NominationsLoadError';
}
