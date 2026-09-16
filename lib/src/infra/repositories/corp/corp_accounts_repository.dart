import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_accounts_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_repository_base.dart';

/// Corporate account data for the dashboard.
class CorpAccountsRepository extends CorpRepositoryBase {
  CorpAccountsRepository({required ObdxCorpAccountsApi accountsApi})
      : _accountsApi = accountsApi;

  final ObdxCorpAccountsApi _accountsApi;

  /// The dashboard's primary load: every account plus the host's per-group
  /// summary, from `GET /digx-common/account/v1/accounts`.
  ///
  /// Falls back to the CASA-only `dda/v1/demandDeposit` endpoint if the
  /// aggregated call fails — that endpoint is confirmed available to the
  /// same corporate session (capture entry #38), so a host that has the
  /// aggregated resource disabled still gets a populated dashboard rather
  /// than an error screen.
  Future<ResponseHandler<CorpAccountsSummary>> fetchAccounts() async {
    try {
      final aggregated = await _accountsApi.fetchAccounts();
      final parsed = await parseBody(
        aggregated,
        CorpAccountsSummary.fromPayload,
      );
      if (parsed is Success<CorpAccountsSummary> &&
          parsed.data != null &&
          !parsed.data!.isEmpty) {
        return parsed;
      }

      final fallback = await _accountsApi.fetchDemandDepositAccounts();
      final fallbackParsed = await parseBody(
        fallback,
        CorpAccountsSummary.fromPayload,
      );
      // Prefer whichever call actually produced accounts; if neither did,
      // keep the aggregated result so an empty-but-successful response
      // still renders the real "no accounts" state.
      if (fallbackParsed is Success<CorpAccountsSummary> &&
          fallbackParsed.data != null &&
          !fallbackParsed.data!.isEmpty) {
        return fallbackParsed;
      }
      return parsed;
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Term / recurring deposits — `GET /digx-common/td/v1/deposit`.
  Future<ResponseHandler<List<CorpAccount>>> fetchDeposits() async {
    try {
      final result = await _accountsApi.fetchDeposits();
      return parseBody(
        result,
        (body) => CorpAccount.listFromPayload(
          body,
          groupOverride: CorpAccountGroup.deposit,
        ),
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Loans & finances — `GET /digx-common/loan/v1/loan`.
  Future<ResponseHandler<List<CorpAccount>>> fetchLoans() async {
    try {
      final result = await _accountsApi.fetchLoans();
      return parseBody(
        result,
        (body) => CorpAccount.listFromPayload(
          body,
          groupOverride: CorpAccountGroup.loan,
        ),
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }
}
