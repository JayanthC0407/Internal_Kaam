import 'package:ubci_bank/src/core/models/corp/corp_loan_application.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_process_management_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_repository_base.dart';

/// Corporate lending applications — the Loan Application Tracker's data.
class CorpLendingRepository extends CorpRepositoryBase {
  CorpLendingRepository({
    required ObdxCorpProcessManagementApi processManagementApi,
  }) : _api = processManagementApi;

  final ObdxCorpProcessManagementApi _api;

  /// Applications in the lending module for [partyId]; empty when there
  /// are none, which is not a failure.
  Future<ResponseHandler<List<CorpLoanApplication>>> fetchLoanApplications(
    String partyId,
  ) async {
    try {
      final result = await _api.fetchProcesses(partyId: partyId);
      return parseBody(result, CorpLoanApplication.listFromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }
}
