import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account_detail.dart';
import 'package:ubci_bank/src/core/models/retail/casa_transaction.dart';
import 'package:ubci_bank/src/core/models/common/statement_format.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_accounts_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// `common/v1/currentDate` (API-05) response.
class BankingDate {
  const BankingDate({this.currentDate, this.nextWorkingDate, this.prevWorkingDate});

  final DateTime? currentDate;
  final DateTime? nextWorkingDate;
  final DateTime? prevWorkingDate;

  factory BankingDate.fromPayload(dynamic data) {
    Map<String, dynamic>? root;
    if (data is Map) {
      root = Map<String, dynamic>.from(data);
      final nested = root['branchDateDefinitionDTO'];
      if (nested is Map) root = Map<String, dynamic>.from(nested);
    }
    root ??= const {};
    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return BankingDate(
      currentDate: parse(root['currentDate']),
      nextWorkingDate: parse(root['nextWorkingDate']),
      prevWorkingDate: parse(root['prevWorkingDate']),
    );
  }
}

class AccountsRepository {
  AccountsRepository({required ObdxAccountsApi accountsApi})
      : _accountsApi = accountsApi;

  final ObdxAccountsApi _accountsApi;

  Future<ResponseHandler<CasaAccountsSummary>> fetchCasaAccounts() async {
    try {
      final result = await _accountsApi.fetchDemandDepositAccounts();
      return _parseSuccessBody(result, CasaAccountsSummary.fromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// `GET /demandDeposit?...&status=CLOSED` (API-03) — CASA accounts
  /// including CLOSED ones, captured as part of the transaction-history
  /// flow. Kept separate from [fetchCasaAccounts] (API-01, ACTIVE/DORMANT
  /// only) so dashboard/list surfaces never show closed accounts by default.
  Future<ResponseHandler<CasaAccountsSummary>>
      fetchCasaAccountsIncludingClosed() async {
    try {
      final result = await _accountsApi.fetchDemandDepositAccounts(
        statuses: const ['ACTIVE', 'DORMANT', 'CLOSED'],
      );
      return _parseSuccessBody(result, CasaAccountsSummary.fromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// `GET /common/v1/currentDate` (API-05) — banking/business date, fetched
  /// as a supporting call in the transaction-history flow.
  Future<ResponseHandler<BankingDate>> fetchCurrentBankingDate() async {
    try {
      final result = await _accountsApi.fetchCurrentDate();
      return _parseSuccessBody(result, BankingDate.fromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// CASA accounts eligible to settle a given transaction task — used by
  /// the loan repayment flow (`taskCode: 'LN_F_LRP'`) to populate the
  /// "pay from" account picker.
  Future<ResponseHandler<List<CasaAccount>>> fetchSettlementAccounts({
    required String taskCode,
  }) async {
    try {
      final result = await _accountsApi.fetchAccountsForTask(taskCode);
      return _parseSuccessBody(result, CasaAccount.listFromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<CasaAccountDetail>> fetchCasaAccountDetail(
    String accountId,
  ) async {
    try {
      final result = await _accountsApi.fetchDemandDepositAccount(accountId);
      return _parseSuccessBody(result, (body) {
        final detail = CasaAccountDetail.fromPayload(body);
        if (detail == null) {
          throw StateError('Empty account detail');
        }
        return detail;
      });
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<CasaTransactionsResult>> fetchCasaTransactions(
    String accountId, {
    CasaTransactionQuery query = const CasaTransactionQuery(),
  }) async {
    try {
      final result = await _accountsApi.fetchDemandDepositTransactions(
        accountId,
        queryParameters: query.toQueryParameters(),
      );
      return _parseSuccessBody(
        result,
        CasaTransactionsResult.fromPayload,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Available statement download formats (CSV/PDF/QIF/OFX per the
  /// `dda/v1/enumerations/mediatype` capture) — used to populate the
  /// format picker before downloading.
  Future<ResponseHandler<List<StatementFormat>>> fetchStatementFormats() async {
    try {
      final result = await _accountsApi.fetchMediaTypes();
      return _parseSuccessBody(result, StatementFormat.listFromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<StatementFile>> downloadStatement(
    String accountId, {
    required StatementFormat format,
    CasaTransactionQuery query = const CasaTransactionQuery(),
    String? transactionsPath,
  }) async {
    try {
      final result = await _accountsApi.downloadStatement(
        accountId,
        media: format.mimeType,
        mediaFormat: format.code,
        queryParameters: query.toQueryParameters(),
        transactionsPath: transactionsPath,
      );
      // Shared with Bill Payment History (statement_download.dart).
      return decodeStatementDownload(
        result,
        format: format,
        fileName: statementFileName(accountId, format.fileExtension),
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Kept for any existing PDF-only call sites.
  Future<ResponseHandler<StatementFile>> downloadStatementPdf(
    String accountId, {
    CasaTransactionQuery query = const CasaTransactionQuery(),
  }) {
    return downloadStatement(
      accountId,
      format: const StatementFormat(code: 'pdf', mimeType: 'application/pdf'),
      query: query,
    );
  }

  Future<ResponseHandler<T>> _parseSuccessBody<T>(
    ResponseHandler<Map<String, dynamic>> result,
    T Function(Map<String, dynamic> body) parse,
  ) async {
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return _mapFailure(result);
    }

    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);

    if (statusCode != StatusCode.OK) {
      final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    if (ObdxApiUtils.hasErrorMessage(body)) {
      final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    try {
      final parsed = parse(body);
      return ResponseHandler.success(parsed, code: statusCode);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  ResponseHandler<T> _mapFailure<T>(ResponseHandler<dynamic> result) {
    if (result is Error) {
      return ResponseHandler.error(
        result.code,
        result.error,
        requestId: result.requestId,
        obdxError: result.obdxError,
      );
    }
    if (result is NetworkError) {
      return ResponseHandler.networkError(obdxError: result.obdxError);
    }
    return ResponseHandler.exceptionError();
  }
}
