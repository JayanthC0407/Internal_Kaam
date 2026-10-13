import 'package:dio/dio.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/common/obdx_batch.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
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
  }) =>
      _postPayment(
        ApiConst.paymentsPayNetworkApi,
        body,
        validateOnly: validateOnly,
        challengeResponseHeader: challengeResponseHeader,
      );

  /// `POST …/pay/networkInstruction` — a repeat (standing-instruction)
  /// transfer. Same headers and 417/OTP handling as [postPayNetwork].
  Future<ResponseHandler<Map<String, dynamic>>> postPayNetworkInstruction(
    Map<String, dynamic> body, {
    bool validateOnly = false,
    String? challengeResponseHeader,
  }) =>
      _postPayment(
        ApiConst.paymentsPayNetworkInstructionApi,
        body,
        validateOnly: validateOnly,
        challengeResponseHeader: challengeResponseHeader,
      );

  /// `POST /digx-payments/batch` — [items] in one multipart request, as
  /// OBDX's Multiple Transfers sends them. [batchType] is `X-BATCH_TYPE`
  /// (see `ObdxBatchType`). The bank asks for one OTP for the whole batch
  /// (417 + `X-CHALLENGE`), so 417 is answered rather than thrown, as for
  /// [postPayNetwork].
  Future<ResponseHandler<Map<String, dynamic>>> postBatch(
    List<ObdxBatchItem> items, {
    required String batchType,
    String? challengeResponseHeader,
    String? boundary,
  }) async {
    try {
      final separator = boundary ?? ObdxBatchEncoder.newBoundary();
      final contentType = 'multipart/form-data; boundary=$separator';
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.paymentsBatchApi),
        data: ObdxBatchEncoder.encode(items, separator),
        options: Options(
          contentType: contentType,
          headers: {
            ApiConst.contentTypeKey: contentType,
            // The servlet splits the body on this header, not the
            // Content-Type parameter.
            'boundary': separator,
            'X-BATCH_TYPE': batchType,
            if (challengeResponseHeader != null &&
                challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: _batchValidateStatus,
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// The batch answers 200 (or 207, multi-status) with a result per part
  /// even when some parts failed, or 417 when it needs an OTP.
  static bool _batchValidateStatus(int? status) =>
      status != null &&
      (status == StatusCode.OK ||
          status == StatusCode.MULTI_STATUS ||
          status == ApiConst.expectationFailed);

  /// `GET …/pay/network/currencies` — International Low Value Payment
  /// currencies with their min/max.
  Future<ResponseHandler<Map<String, dynamic>>> fetchGpiCurrencies() =>
      _get(ApiConst.paymentsGpiCurrenciesApi);

  /// `GET …/maintenances/networkPurposeMapping?networkCode=`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchNetworkPurposes(
    String networkCode,
  ) =>
      _get(ApiConst.paymentsNetworkPurposesApi, {'networkCode': networkCode});

  /// `GET …/fetchNetworkCodeDetails/{clearingCode}?network=` — the bank
  /// behind a domestic clearing code.
  Future<ResponseHandler<Map<String, dynamic>>> fetchNetworkCodeDetails({
    required String clearingCode,
    required String network,
  }) =>
      _get(
        ApiConst.paymentsNetworkCodeDetailsApi(clearingCode),
        {'network': network},
      );

  /// `GET …/financialInstitution/bicCodeDetails/{BICCode}`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBicDetails(String bic) =>
      _get(ApiConst.paymentsBicDetailsApi(bic));

  /// `GET …/enumerations/paymentFrequency`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchFrequencies() =>
      _get(ApiConst.paymentsFrequencyEnumApi);

  /// `GET …/payments/instructions` — repeat transfers, a page at a time.
  /// [status] `ACTIVE` or `CANCELLED`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchInstructions({
    required String status,
    int pageSize = 50,
    int pageNumber = 1,
  }) =>
      _get(ApiConst.paymentsInstructionsApi, {
        'status': status,
        'pageSize': pageSize,
        'pageNumber': pageNumber,
      });

  /// `GET …/payments/instructions/{reference}?partyId=` — with its history.
  Future<ResponseHandler<Map<String, dynamic>>> fetchInstruction(
    String reference, {
    String? partyId,
  }) =>
      _get(ApiConst.paymentsInstructionApi(reference), {
        if (partyId != null && partyId.isNotEmpty) 'partyId': partyId,
      });

  /// Stopping an instruction, step 1 of 2: `POST …/sicancellation/{ref}`.
  Future<ResponseHandler<Map<String, dynamic>>> startInstructionStop(
    String reference,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.paymentsInstructionStopApi(reference)),
        data: body,
        options: Options(headers: _jsonHeaders),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// Step 2 of 2: `PATCH …/sicancellation/{ref}` confirms the stop. The bank
  /// may answer 417 + `X-CHALLENGE` (OTP) — answered, not thrown, and
  /// repeated with [challengeResponseHeader] — or 202 when an approver has
  /// to agree.
  Future<ResponseHandler<Map<String, dynamic>>> confirmInstructionStop(
    String reference,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) async {
    try {
      final response = await dio.patch(
        ObdxApiUtils.appendLocaleQuery(ApiConst.paymentsInstructionStopApi(reference)),
        data: body,
        options: Options(
          headers: {
            ..._jsonHeaders,
            if (challengeResponseHeader != null && challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: (status) =>
              status == StatusCode.OK ||
              status == StatusCode.ACCEPTED ||
              status == ApiConst.expectationFailed,
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> _get(
    String path, [
    Map<String, dynamic> query = const {},
  ]) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: query,
        options: Options(headers: _jsonHeaders),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> _postPayment(
    String path,
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
        ObdxApiUtils.appendLocaleQuery(path),
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
