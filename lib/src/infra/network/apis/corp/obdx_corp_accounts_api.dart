import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Corporate account APIs — the aggregated account list that backs the
/// dashboard's Account Summary grid and the Accounts / Deposits / Loans
/// card, plus the per-group list endpoints.
///
/// Auth (`Authorization` / `X-Token-Type`), `X-Target-Unit` and the `locale`
/// query parameter are all applied for us by `AuthorizationInterceptor` and
/// `ObdxApiUtils.appendLocaleQuery`, exactly as for the Retail APIs.
class ObdxCorpAccountsApi extends ObdxApiBase {
  ObdxCorpAccountsApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  /// `GET /digx-common/account/v1/accounts` — every account the corporate
  /// user can see, with the host's `summary.items[]` roll-up.
  ///
  /// The capture sends no filters at all, so none are sent by default;
  /// [accountTypes] / [statuses] are available for narrower call sites
  /// (e.g. a future "closed accounts" view) and are omitted when empty.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccounts({
    List<String> accountTypes = const [],
    List<String> statuses = const [],
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(CorpApiConst.accountsApi),
        queryParameters: {
          if (accountTypes.isNotEmpty) 'accountType': accountTypes,
          if (statuses.isNotEmpty) 'status': statuses,
        },
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET /digx-common/dda/v1/demandDeposit` — CASA-only fallback for hosts
  /// where the aggregated [fetchAccounts] endpoint is not enabled for
  /// corporate users.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDemandDepositAccounts({
    List<String> accountTypes = const ['CURRENT', 'SAVING'],
    List<String> statuses = const ['ACTIVE', 'DORMANT'],
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(CorpApiConst.demandDepositApi),
        queryParameters: {
          'accountType': accountTypes.join(','),
          'status': statuses,
        },
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET /digx-common/td/v1/deposit?module=CON&module=ISL` — term and
  /// recurring deposits for the card's "Deposits" tab.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDeposits({
    List<String> modules = CorpApiConst.depositModules,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(CorpApiConst.depositsApi),
        queryParameters: {
          if (modules.isNotEmpty) 'module': modules,
        },
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET /digx-common/loan/v1/loan` — loans & finances for the card's
  /// "Loans" tab.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLoans() async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(CorpApiConst.loansApi),
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }
}
