import 'package:ubci_bank/src/core/models/retail/certificate_models.dart';
import 'package:ubci_bank/src/core/models/retail/nomination_models.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_nominations_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Nominations: parses [ObdxNominationsApi] answers.
/// docs/obdx/features/nominations.md.
class NominationsRepository extends ObdxRepositoryBase {
  NominationsRepository({required ObdxNominationsApi api}) : _api = api;

  final ObdxNominationsApi _api;

  /// The Account Number picker: `accounts[]` (`id`), as for Certificates.
  Future<ResponseHandler<List<CertificateAccount>>> fetchPickerAccounts(NominationCategory c) async =>
      parseBody(await _api.fetchPickerAccounts(c), CertificateAccount.listFromPayload);

  Future<ResponseHandler<List<NominationRow>>> fetchRows(NominationCategory c) async =>
      parseBody(await _api.fetchNominationRows(c), NominationRow.listFromPayload);

  Future<ResponseHandler<Nominee>> fetchNominee(String accountId) async =>
      parseBody(await _api.fetchNominee(accountId), (body) {
        final nominee = Nominee.fromPayload(body);
        if (nominee == null) throw StateError('No nomineeDTO');
        return nominee;
      });

  /// Relation value → description.
  Future<ResponseHandler<Map<String, String>>> fetchRelations() async =>
      parseBody(await _api.fetchRelations(), (b) => nomineeEnumDescriptions(b, key: 'value'));

  /// Country code → description.
  Future<ResponseHandler<Map<String, String>>> fetchCountries() async =>
      parseBody(await _api.fetchCountries(), (b) => nomineeEnumDescriptions(b, key: 'code'));
}
