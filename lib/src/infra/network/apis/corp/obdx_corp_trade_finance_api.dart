import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_trade_finance_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Trade Finance — Letter of Credit APIs.
///
/// Every method returns the `{ statusCode, headers, body }` envelope from
/// [ObdxApiUtils.wrapHttpResponse]; parsing and error mapping live in
/// `CorpTradeFinanceRepository`. See [CorpTradeFinanceApiConst] for the
/// capture entry behind each path.
class ObdxCorpTradeFinanceApi extends ObdxApiBase {
  ObdxCorpTradeFinanceApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  static const _conventional = CorpTradeFinanceApiConst.conventional;

  static Options get _json => Options(
        headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
      );

  /// Accepts 2xx plus 417 so a step-up challenge is readable from the
  /// response instead of surfacing as a Dio error (same as payments).
  static bool _submitValidateStatus(int? status) =>
      status != null &&
      ((status >= 200 && status < 300) ||
          status == ApiConst.expectationFailed);

  static String _criteria(List<Map<String, dynamic>> criteria) =>
      jsonEncode({'criteria': criteria});

  Future<ResponseHandler<Map<String, dynamic>>> _run(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final response = await call();
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) {
    return _run(() => dio.get(
          ObdxApiUtils.appendLocaleQuery(path),
          queryParameters: query,
          options: _json,
        ));
  }

  // ── Letter of Credit ─────────────────────────────────────────────────

  /// `GET …/letterofcredits` — H1 #46 / H1 #138 / H2 #138.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLetterOfCredits({
    required String lcType,
    String? partyId,
    String? lcStatus,
    bool amendableOnly = false,
  }) {
    return _get(CorpTradeFinanceApiConst.letterOfCreditsApi, {
      if (amendableOnly) 'isAmendable': 'TRUE',
      if (lcStatus != null) 'lcStatus': lcStatus,
      'lcType': lcType,
      if (partyId != null && partyId.isNotEmpty) 'partyIds': partyId,
      'transactionType': _conventional,
    });
  }

  /// `GET …/letterofcredits/{id}` — H1 #48 / H1 #141.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLetterOfCredit(
    String id, {
    String? versionNo,
  }) {
    return _get(CorpTradeFinanceApiConst.letterOfCreditApi(id), {
      'transactionType': _conventional,
      if (versionNo != null) 'versionNo': versionNo,
    });
  }

  /// `GET …/letterofcredits/drafts` — H1 #90.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDrafts() {
    return _get(CorpTradeFinanceApiConst.draftsApi, {
      'transactionType': _conventional,
    });
  }

  /// `POST …/letterofcredits` — create a draft (H1 #71, 201) or submit.
  Future<ResponseHandler<Map<String, dynamic>>> createLetterOfCredit(
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) {
    return _run(() => dio.post(
          ObdxApiUtils.appendLocaleQuery(
            CorpTradeFinanceApiConst.letterOfCreditsApi,
          ),
          data: body,
          options: Options(
            headers: {
              ApiConst.contentTypeKey: ApiConst.contentTypeValue,
              if (challengeResponseHeader != null)
                ApiConst.xChallengeResponse: challengeResponseHeader,
            },
            validateStatus: _submitValidateStatus,
          ),
        ));
  }

  /// `PUT …/letterofcredits/{id}` — update a draft (H1 #74..#79).
  Future<ResponseHandler<Map<String, dynamic>>> updateLetterOfCredit(
    String id,
    Map<String, dynamic> body,
  ) {
    return _run(() => dio.put(
          ObdxApiUtils.appendLocaleQuery(
            CorpTradeFinanceApiConst.letterOfCreditApi(id),
          ),
          data: body,
          options: _json,
        ));
  }

  /// `DELETE …/letterofcredits/{id}` — discard a draft (H1 #80).
  Future<ResponseHandler<Map<String, dynamic>>> deleteLetterOfCredit(
    String id,
  ) {
    return _run(() => dio.delete(
          ObdxApiUtils.appendLocaleQuery(
            CorpTradeFinanceApiConst.letterOfCreditApi(id),
          ),
          options: _json,
        ));
  }

  /// `POST …/letterofcredits/charges` — charge preview (H1 #121).
  Future<ResponseHandler<Map<String, dynamic>>> fetchCharges(
    Map<String, dynamic> body,
  ) {
    return _run(() => dio.post(
          ObdxApiUtils.appendLocaleQuery(CorpTradeFinanceApiConst.chargesApi),
          data: body,
          options: _json,
        ));
  }

  /// `POST …/letterofcredits/{lcId}/amendments` — H1 #204.
  Future<ResponseHandler<Map<String, dynamic>>> submitAmendment(
    String lcId,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) {
    return _run(() => dio.post(
          ObdxApiUtils.appendLocaleQuery(
            CorpTradeFinanceApiConst.amendmentsApi(lcId),
          ),
          data: body,
          options: Options(
            headers: {
              ApiConst.contentTypeKey: ApiConst.contentTypeValue,
              if (challengeResponseHeader != null)
                ApiConst.xChallengeResponse: challengeResponseHeader,
            },
            validateStatus: _submitValidateStatus,
          ),
        ));
  }

  /// `POST …/letterofcredits/{lcId}/amendments/charges` — H1 #177.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAmendmentCharges(
    String lcId,
    Map<String, dynamic> body,
  ) {
    return _run(() => dio.post(
          ObdxApiUtils.appendLocaleQuery(
            CorpTradeFinanceApiConst.amendmentChargesApi(lcId),
          ),
          data: body,
          options: _json,
        ));
  }

  // ── Export LC ────────────────────────────────────────────────────────

  /// Export LCs that can still be transferred — H2 #202.
  Future<ResponseHandler<Map<String, dynamic>>> fetchTransferableLcs({
    String? partyId,
  }) {
    return _get(CorpTradeFinanceApiConst.letterOfCreditsApi, {
      'fromTransferrableAmount': '1',
      'lcStatus': 'ACTIVE',
      'lcType': 'Export',
      if (partyId != null && partyId.isNotEmpty) 'partyIds': partyId,
      'transactionType': _conventional,
      'transferrable': 'true',
    });
  }

  /// Export amendments awaiting our acceptance — H2 #157.
  Future<ResponseHandler<Map<String, dynamic>>> fetchExportAmendments({
    String? partyId,
  }) {
    return _get(CorpTradeFinanceApiConst.amendmentListApi, {
      if (partyId != null && partyId.isNotEmpty) 'partyIds': partyId,
      'transactionType': _conventional,
      'type': 'EXPORT',
    });
  }

  /// Accept / reject an export amendment (NOT CAPTURED — see constants).
  Future<ResponseHandler<Map<String, dynamic>>> respondToAmendment(
    String lcId,
    String amendmentId,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) {
    return _run(() => dio.put(
          ObdxApiUtils.appendLocaleQuery(
            CorpTradeFinanceApiConst.amendmentApi(lcId, amendmentId),
          ),
          data: body,
          options: _submitOptions(challengeResponseHeader),
        ));
  }

  /// Transfer an Export LC (NOT CAPTURED — see constants).
  Future<ResponseHandler<Map<String, dynamic>>> initiateTransfer(
    String lcId,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) {
    return _run(() => dio.post(
          ObdxApiUtils.appendLocaleQuery(
            CorpTradeFinanceApiConst.transfersApi(lcId),
          ),
          data: body,
          options: _submitOptions(challengeResponseHeader),
        ));
  }

  static Options _submitOptions(String? challengeResponseHeader) => Options(
        headers: {
          ApiConst.contentTypeKey: ApiConst.contentTypeValue,
          if (challengeResponseHeader != null)
            ApiConst.xChallengeResponse: challengeResponseHeader,
        },
        validateStatus: _submitValidateStatus,
      );

  // ── Products & configuration ─────────────────────────────────────────

  /// H1 #51.
  Future<ResponseHandler<Map<String, dynamic>>> fetchProducts() {
    return _get(CorpTradeFinanceApiConst.productsApi, {
      'transactionType': _conventional,
    });
  }

  /// H1 #159.
  Future<ResponseHandler<Map<String, dynamic>>> fetchProductDocuments(
    String productId,
  ) {
    return _get(CorpTradeFinanceApiConst.productDocumentsApi(productId));
  }

  /// H1 #44.
  Future<ResponseHandler<Map<String, dynamic>>> fetchConfigurations() {
    return _get(CorpTradeFinanceApiConst.configurationsApi);
  }

  // ── Lookups ──────────────────────────────────────────────────────────

  /// `tradeEnumerations/{name}` — H1 #42 / #115 / #117 / #142.
  Future<ResponseHandler<Map<String, dynamic>>> fetchEnumeration(String name) {
    return _get(CorpTradeFinanceApiConst.enumerationApi(name));
  }

  /// H1 #102.
  Future<ResponseHandler<Map<String, dynamic>>> fetchGoods() {
    return _get(CorpTradeFinanceApiConst.goodsApi, {
      'queryParams': _criteria([
        {
          'operand': 'transactionType',
          'operator': 'EQUALS',
          'value': [_conventional],
        },
      ]),
    });
  }

  /// H1 #106.
  Future<ResponseHandler<Map<String, dynamic>>> fetchIncoterms() {
    return _get(CorpTradeFinanceApiConst.incotermsApi);
  }

  /// H1 #104.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAdditionalConditions() {
    return _get(CorpTradeFinanceApiConst.additionalConditionsApi);
  }

  /// H1 #143.
  Future<ResponseHandler<Map<String, dynamic>>> lookupBic(String swiftCode) {
    return _get(CorpTradeFinanceApiConst.bicCodesApi, {
      'q': _criteria([
        {
          'operand': 'swiftCode',
          'operator': 'EQUALS',
          'value': [swiftCode],
        },
      ]),
    });
  }
}
