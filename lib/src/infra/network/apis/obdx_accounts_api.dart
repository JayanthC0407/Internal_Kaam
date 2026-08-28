import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// CASA demand-deposit list, detail, transactions, and statement PDF.
class ObdxAccountsApi extends ObdxApiBase {
  ObdxAccountsApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  /// `GET /digx-common/dda/v1/demandDeposit?accountType=CURRENT,SAVING&status=ACTIVE&status=DORMANT`
  Future<ResponseHandler<Map<String, dynamic>>> fetchDemandDepositAccounts({
    List<String> accountTypes = const ['CURRENT', 'SAVING'],
    List<String> statuses = const ['ACTIVE', 'DORMANT'],
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.accountsApiDemandDeposit),
        queryParameters: {
          'accountType': accountTypes.join(','),
          'status': statuses,
        },
        options: Options(
          headers: {ApiConst.contentTypeKey: 'application/json'},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// Alias for [fetchDemandDepositAccounts] — kept for call-site clarity.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccounts() =>
      fetchDemandDepositAccounts();

  /// `GET /digx-common/dda/v1/demandDeposit?taskCode={taskCode}` — accounts
  /// eligible for a given transaction task (e.g. `LN_F_LRP` for loan
  /// repayment settlement account selection).
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccountsForTask(
    String taskCode,
  ) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.accountsApiDemandDeposit),
        queryParameters: {'taskCode': taskCode},
        options: Options(
          headers: {ApiConst.contentTypeKey: 'application/json'},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET /digx-common/dda/v1/demandDeposit/{accountId}`
  Future<ResponseHandler<Map<String, dynamic>>> fetchDemandDepositAccount(
    String accountId,
  ) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(
          ApiConst.demandDepositAccountApi(accountId),
        ),
        options: Options(
          headers: {ApiConst.contentTypeKey: 'application/json'},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET /digx-common/dda/v1/demandDeposit/{accountId}/transactions`
  ///
  /// Defaults (unfiltered): `searchBy=CPR`, `transactionType=A` (all).
  /// Extra keys (amount, referenceNumber) are sent only when provided.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDemandDepositTransactions(
    String accountId, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(
          ApiConst.demandDepositTransactionsApi(accountId),
        ),
        queryParameters: {
          'searchBy': 'CPR',
          'transactionType': 'A',
          ...?queryParameters,
        },
        options: Options(
          headers: {ApiConst.contentTypeKey: 'application/json'},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET /digx-common/dda/v1/demandDeposit/{accountId}/transactions`
  /// with `media=application/pdf&mediaFormat=pdf` (Postman Statement Download).
  Future<ResponseHandler<List<int>>> downloadStatementPdf(
    String accountId, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get<List<int>>(
        ObdxApiUtils.appendLocaleQuery(
          ApiConst.demandDepositTransactionsApi(accountId),
        ),
        queryParameters: {
          // Pass unencoded; Dio encodes once → application%2Fpdf (Postman shape).
          'media': 'application/pdf',
          'mediaFormat': 'pdf',
          'searchBy': 'CPR',
          'transactionType': 'A',
          ...?queryParameters,
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Accept': 'application/pdf, application/octet-stream, application/json, */*',
          },
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return ResponseHandler.exceptionError();
      }
      return ResponseHandler.success(
        List<int>.from(bytes),
        code: response.statusCode ?? 0,
      );
    } on DioException catch (error) {
      return getErrorResponse<List<int>>(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse<List<int>>(exc, stack);
    }
  }

  /// `GET /digx-common/dda/v1/enumerations/mediatype`
  Future<ResponseHandler<Map<String, dynamic>>> fetchMediaTypes() async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.demandDepositMediaTypeApi),
        options: Options(
          headers: {ApiConst.contentTypeKey: 'application/json'},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET /digx-common/common/v1/currentDate`
  Future<ResponseHandler<Map<String, dynamic>>> fetchCurrentDate() async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.commonCurrentDateApi),
        options: Options(
          headers: {ApiConst.contentTypeKey: 'application/json'},
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
