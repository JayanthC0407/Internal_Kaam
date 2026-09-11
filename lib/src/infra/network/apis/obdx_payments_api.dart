import 'package:dio/dio.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX payments APIs for own-account transfer (SELFFT / SELF network).
class ObdxPaymentsApi extends ObdxApiBase {
  ObdxPaymentsApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  static Map<String, String> get _jsonHeaders =>
      {ApiConst.contentTypeKey: ApiConst.contentTypeValue};

  /// `GET …/payments/fetchNetwork` — OBDX API Reference V1.1.
  Future<ResponseHandler<Map<String, dynamic>>> fetchNetworks() async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.paymentsFetchNetworkApi),
        options: Options(headers: _jsonHeaders),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET …/payments/maintenance` — OBDX API Reference V1.1.
  Future<ResponseHandler<Map<String, dynamic>>> fetchMaintenance() async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.paymentsMaintenanceApi),
        options: Options(headers: _jsonHeaders),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET …/payments/currentDate?branchCode=001`
  Future<ResponseHandler<Map<String, dynamic>>> fetchCurrentDate({
    String branchCode = '001',
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.paymentsCurrentDateApi),
        queryParameters: {'branchCode': branchCode},
        options: Options(headers: _jsonHeaders),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET …/payments/currencies?currency=GHS&type=SELFFT`
  Future<ResponseHandler<Map<String, dynamic>>> fetchCurrencies({
    required String currency,
    String type = ApiConst.selfTransferType,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.paymentsCurrenciesApi),
        queryParameters: {
          'currency': currency,
          'type': type,
        },
        options: Options(headers: _jsonHeaders),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET …/payments/charges`
  Future<ResponseHandler<Map<String, dynamic>>> fetchCharges({
    required String accountId,
    required String accountType,
    required double amount,
    required String currency,
    required String paymentDate,
    String network = ApiConst.selfTransferNetwork,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.paymentsChargesApi),
        queryParameters: {
          'accountId': accountId,
          'accountType': accountType,
          'amount': amount,
          'currency': currency,
          'network': network,
          'paymentDate': paymentDate,
        },
        options: Options(headers: _jsonHeaders),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `GET …/payments/genericPaymentDate` — validates scheduled transfer date.
  Future<ResponseHandler<Map<String, dynamic>>> fetchGenericPaymentDate({
    required String accountId,
    required String accountType,
    required String activationDate,
    required double amount,
    required String currency,
    required String debitCurrency,
    String networkCode = ApiConst.selfTransferNetwork,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.paymentsGenericPaymentDateApi),
        queryParameters: {
          'accountId': accountId,
          'accountType': accountType,
          'activationDate': activationDate,
          'amount': amount,
          'currency': currency,
          'debitCurrency': debitCurrency,
          'networkCode': networkCode,
        },
        options: Options(headers: _jsonHeaders),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  static bool _submitValidateStatus(int? status) {
    return status != null &&
        (status == StatusCode.OK || status == ApiConst.expectationFailed);
  }

  /// `POST …/pay/network` with optional validate-only / OTP challenge headers.
  ///
  /// Validate-only keeps default 2xx handling. Submit accepts HTTP 417 so the
  /// repository can parse `X-Challenge` without treating it as a Dio error.
  Future<ResponseHandler<Map<String, dynamic>>> postPayNetwork(
    Map<String, dynamic> body, {
    bool validateOnly = false,
    String? challengeResponseHeader,
  }) async {
    try {
      final headers = Map<String, String>.from(_jsonHeaders);
      if (validateOnly) {
        headers['X-Validate-Only'] = 'true';
      }
      if (!validateOnly &&
          challengeResponseHeader != null &&
          challengeResponseHeader.isNotEmpty) {
        headers[ApiConst.xChallengeResponse] = challengeResponseHeader;
      }
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.paymentsPayNetworkApi),
        data: body,
        options: Options(
          headers: headers,
          validateStatus: validateOnly ? null : _submitValidateStatus,
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
