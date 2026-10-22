import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX Bill Payments (EBPP) — Billers.
///
/// Mirrors `components/bill-payments/manage-bill-payments/model.js` in the
/// original OBDX source; see docs/obdx/features/bill-payments.md §3 for the
/// evidence behind each call. Common (not retail-only): the corporate menu
/// has Billers too.
class ObdxBillPaymentsApi extends ObdxApiBase {
  ObdxBillPaymentsApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  static const _registeredBillers =
      '/digx-payments/ebpp/v1/registeredBillers';
  static const _billers = '/digx-payments/ebpp/v1/billers';
  static const _ebillPayments = '/digx-payments/ebpp/v1/ebillPayments';

  /// `GET …/ebpp/v1/registeredBillers` — the user's billers
  /// (`billerRegistrationDTOs`). OBDX sends no filters here.
  Future<ResponseHandler<Map<String, dynamic>>> fetchRegisteredBillers() =>
      _get(_registeredBillers);

  /// `GET …/ebpp/v1/registeredBillers/{billerRegistrationId}` — one biller
  /// (`billerRegistration`); unlike the list item it has no embedded `biller`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchRegisteredBiller(
    String billerRegistrationId,
  ) =>
      _get('$_registeredBillers/${Uri.encodeComponent(billerRegistrationId)}');

  /// `GET …/ebpp/v1/billers/{billerId}` — the biller master (`biller`).
  Future<ResponseHandler<Map<String, dynamic>>> fetchBiller(String billerId) =>
      _get('$_billers/${Uri.encodeComponent(billerId)}');

  /// `GET …/ebpp/v1/ebillPayments` — Bill Payment History
  /// (`billPaymentDTOs`); [queryParameters] carries `searchBy` and, for a
  /// date range, `fromDate`/`toDate` (payment-history/model.js:24-43).
  Future<ResponseHandler<Map<String, dynamic>>> fetchBillPayments(
    Map<String, dynamic> queryParameters,
  ) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(_ebillPayments),
        queryParameters: queryParameters,
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

  /// `GET …/ebpp/v1/billers` — every biller the bank offers
  /// (`billerDTOs`); Add Billers' list. OBDX sends no filters.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBillers() => _get(_billers);

  /// `POST …/ebpp/v1/registeredBillers` — Add Billers. UAT answers 201
  /// with `billerRegistration`. OTP was off in the capture, but OBDX
  /// handles 417 + `X-CHALLENGE` on every call (2fa-interrupt.js:67), so
  /// 417 and 202 come back as results and a 417 is retried with
  /// [challengeResponseHeader].
  Future<ResponseHandler<Map<String, dynamic>>> addRegisteredBiller(
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(_registeredBillers),
        data: body,
        options: Options(
          headers: {
            ApiConst.contentTypeKey: ApiConst.contentTypeValue,
            if (challengeResponseHeader != null &&
                challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: (status) =>
              status == 200 || status == 201 || status == 202 || status == 417,
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `DELETE …/ebpp/v1/registeredBillers/{billerRegistrationId}`.
  ///
  /// OBDX sends the biller row as the request body; whether the server needs
  /// it is unverified, so [body] is optional. The response is not yet seen
  /// in UAT: 200 / 202 (sent for approval) / 417 + `X-CHALLENGE` (OTP) are
  /// returned as results rather than thrown, the same as payee delete, and
  /// a 417 is retried with [challengeResponseHeader].
  Future<ResponseHandler<Map<String, dynamic>>> deleteRegisteredBiller(
    String billerRegistrationId, {
    Map<String, dynamic>? body,
    String? challengeResponseHeader,
  }) async {
    try {
      final response = await dio.delete(
        ObdxApiUtils.appendLocaleQuery(
          '$_registeredBillers/${Uri.encodeComponent(billerRegistrationId)}',
        ),
        data: body,
        options: Options(
          headers: {
            ApiConst.contentTypeKey: ApiConst.contentTypeValue,
            if (challengeResponseHeader != null &&
                challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: (status) =>
              status == 200 || status == 202 || status == 417,
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// `PUT …/ebpp/v1/registeredBillers/{billerRegistrationId}` — Edit Biller
  /// (modify-biller-review/model.js:11-20). Response not yet seen in UAT;
  /// 200/201/202/417 come back as results like the other writes.
  Future<ResponseHandler<Map<String, dynamic>>> updateRegisteredBiller(
    String billerRegistrationId,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) async {
    try {
      final response = await dio.put(
        ObdxApiUtils.appendLocaleQuery(
          '$_registeredBillers/${Uri.encodeComponent(billerRegistrationId)}',
        ),
        data: body,
        options: Options(
          headers: {
            ApiConst.contentTypeKey: ApiConst.contentTypeValue,
            if (challengeResponseHeader != null &&
                challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: (status) =>
              status == 200 || status == 201 || status == 202 || status == 417,
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> _get(String path) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
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
