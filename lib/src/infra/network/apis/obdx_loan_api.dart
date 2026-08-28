import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Loan and finance APIs (`GET /digx-common/loan/v1/loan`).
class ObdxLoanApi extends ObdxApiBase {
  ObdxLoanApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  /// `GET /digx-common/loan/v1/loan` — balance overview / loan list.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLoans() async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.loanApi),
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

  /// `GET /digx-common/loan/v1/loan/{id}?module=CON` — single loan overview.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLoanDetails(
    String loanId, {
    String? module,
  }) => _getLoanSubResource(ApiConst.loanDetailsApi(loanId), module: module);

  /// `GET /digx-common/loan/v1/loan/{id}/schedule?module=CON` — repayment
  /// schedule (installment-by-installment breakdown).
  Future<ResponseHandler<Map<String, dynamic>>> fetchLoanSchedule(
    String loanId, {
    String? module,
  }) => _getLoanSubResource(ApiConst.loanScheduleApi(loanId), module: module);

  /// `GET /digx-common/loan/v1/loan/{id}/outstanding?module=CON` — current
  /// outstanding balance breakdown (principal / interest / charges).
  ///
  /// [repaymentType] (`P` = partial/principal repayment in the captured
  /// flow) is required by the repayment screen's outstanding-amount lookup;
  /// omit it for the plain read-only details view.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLoanOutstanding(
    String loanId, {
    String? module,
    String? repaymentType,
  }) =>
      _getLoanSubResource(
        ApiConst.loanOutstandingApi(loanId),
        module: module,
        extraQuery: {
          if (repaymentType != null && repaymentType.isNotEmpty)
            'repaymentType': repaymentType,
        },
      );

  /// `GET /digx-common/loan/v1/loan/{id}/disbursements?module=CON` —
  /// disbursement history for the loan.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLoanDisbursements(
    String loanId, {
    String? module,
  }) => _getLoanSubResource(
        ApiConst.loanDisbursementsApi(loanId),
        module: module,
      );

  /// `POST /digx-common/loan/v1/loan/{id}/repayments` — submit a repayment.
  ///
  /// [challengeResponse], when set, is sent as the `X-CHALLENGE_RESPONSE`
  /// header (`{"otp": ..., "referenceNo": ..., "authType": "OTP"}`) — this
  /// is how a retry after step-up authentication is submitted, confirmed
  /// against the OBDX capture with OTP enabled.
  Future<ResponseHandler<Map<String, dynamic>>> postLoanRepayment(
    String loanId,
    Map<String, dynamic> body, {
    Map<String, dynamic>? challengeResponse,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.loanRepaymentsApi(loanId)),
        data: jsonEncode(body),
        options: Options(
          headers: {
            ApiConst.contentTypeKey: 'application/json',
            if (challengeResponse != null)
              'X-CHALLENGE_RESPONSE': jsonEncode(challengeResponse),
          },
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      // OBDX signals "step-up authentication required" as HTTP 417 with
      // an `X-CHALLENGE` response header — an expected outcome for this
      // endpoint when OTP is enabled, not a failure. Hand the whole
      // response up so the repository can read the challenge instead of
      // collapsing it into a generic error.
      final response = error.response;
      if (response != null && response.statusCode == 417) {
        return ResponseHandler.success(
          ObdxApiUtils.wrapHttpResponse(response),
        );
      }
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> _getLoanSubResource(
    String path, {
    String? module,
    Map<String, dynamic> extraQuery = const {},
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: {
          if (module != null && module.isNotEmpty) 'module': module,
          ...extraQuery,
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

  /// `GET /digx-common/loan/v1/loan/{id}/transactions?searchBy=LNT` —
  /// last [noOfTransactions] transactions for a loan, same convention as
  /// the CASA "recent transactions" endpoint.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLoanTransactions(
    String loanId, {
    int noOfTransactions = 5,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.loanTransactionsApi(loanId)),
        queryParameters: {
          'searchBy': 'LNT',
          'noOfTransactions': noOfTransactions.toString(),
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
}
