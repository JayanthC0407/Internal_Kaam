import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_bank_guarantee_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Trade Finance — Bank Guarantee APIs.
///
/// Every method returns the `{ statusCode, headers, body }` envelope from
/// [ObdxApiUtils.wrapHttpResponse]; parsing and error mapping live in
/// `CorpBankGuaranteeRepository`. See [CorpBankGuaranteeApiConst] for the
/// capture entry behind each path.
class ObdxCorpBankGuaranteeApi extends ObdxApiBase {
  ObdxCorpBankGuaranteeApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  static Options get _json => Options(
        headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
      );

  /// Accepts 2xx plus 417 so a step-up challenge is readable from the
  /// response instead of surfacing as a Dio error (same as payments).
  static bool _submitValidateStatus(int? status) =>
      status != null &&
      ((status >= 200 && status < 300) ||
          status == ApiConst.expectationFailed);

  static Options _submitOptions(String? challengeResponseHeader) => Options(
        headers: {
          ApiConst.contentTypeKey: ApiConst.contentTypeValue,
          if (challengeResponseHeader != null)
            ApiConst.xChallengeResponse: challengeResponseHeader,
        },
        validateStatus: _submitValidateStatus,
      );

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

  // ── Guarantees ───────────────────────────────────────────────────────

  /// `GET …/bankguarantees` — BG #44 / #51 / #76 / #84. [query] comes
  /// ready from `BgSearch.toQuery`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBankGuarantees(
    Map<String, dynamic> query,
  ) {
    return _get(CorpBankGuaranteeApiConst.bankGuaranteesApi, query);
  }

  /// `GET …/bankguarantees` with `media` / `mediaFormat` — the list as a
  /// PDF or CSV file (component `bankguaranteesgetdownloadfile`). Returns
  /// the file's bytes.
  Future<ResponseHandler<List<int>>> downloadBankGuarantees(
    Map<String, dynamic> query, {
    required String media,
    required String mediaFormat,
  }) async {
    try {
      final response = await dio.get<List<int>>(
        ObdxApiUtils.appendLocaleQuery(
          CorpBankGuaranteeApiConst.bankGuaranteesApi,
        ),
        queryParameters: {
          ...query,
          'media': media,
          'mediaFormat': mediaFormat,
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Accept': '$media, application/octet-stream, application/json, */*',
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

  /// `GET …/bankguarantees/{id}` — FROM COMPONENT.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBankGuarantee(
    String id, {
    required String categoryType,
    String? versionNo,
  }) {
    return _get(CorpBankGuaranteeApiConst.bankGuaranteeApi(id), {
      'categoryType': categoryType,
      if (versionNo != null) 'versionNo': versionNo,
    });
  }

  // ── Amendments ───────────────────────────────────────────────────────

  /// `GET …/bankguarantees/amendments` — BG #62 / #63 / #67.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAmendments({
    required String categoryType,
    String type = CorpBankGuaranteeApiConst.inward,
    String? partyId,
  }) {
    return _get(CorpBankGuaranteeApiConst.amendmentsApi, {
      'categoryType': categoryType,
      if (partyId != null && partyId.isNotEmpty) 'partyId': partyId,
      'type': type,
    });
  }

  /// `GET …/bankguarantees/{bgId}/amendments/{id}` — FROM COMPONENT.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAmendment(
    String bankGuaranteeId,
    String amendmentId, {
    required String categoryType,
  }) {
    return _get(
      CorpBankGuaranteeApiConst.amendmentApi(bankGuaranteeId, amendmentId),
      {'categoryType': categoryType},
    );
  }

  /// Accept / reject one amendment — NOT CAPTURED (see constants).
  Future<ResponseHandler<Map<String, dynamic>>> respondToAmendment(
    String bankGuaranteeId,
    String amendmentId,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) {
    return _run(() => dio.put(
          ObdxApiUtils.appendLocaleQuery(
            CorpBankGuaranteeApiConst.amendmentApi(
              bankGuaranteeId,
              amendmentId,
            ),
          ),
          data: body,
          options: _submitOptions(challengeResponseHeader),
        ));
  }

  // ── Claims ───────────────────────────────────────────────────────────

  /// Lodge a claim — NOT CAPTURED (see constants).
  Future<ResponseHandler<Map<String, dynamic>>> lodgeClaim(
    String bankGuaranteeId,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) {
    return _run(() => dio.post(
          ObdxApiUtils.appendLocaleQuery(
            CorpBankGuaranteeApiConst.claimsApi(bankGuaranteeId),
          ),
          data: body,
          options: _submitOptions(challengeResponseHeader),
        ));
  }

  // ── Lookups ──────────────────────────────────────────────────────────

  /// BG #39 (currencies), FROM COMPONENT (demand indicator types).
  Future<ResponseHandler<Map<String, dynamic>>> fetchEnumeration(String name) {
    return _get(CorpBankGuaranteeApiConst.enumerationApi(name));
  }

  /// BG #69.
  Future<ResponseHandler<Map<String, dynamic>>> fetchConfigurations() {
    return _get(CorpBankGuaranteeApiConst.configurationsApi);
  }

  /// BG #75.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBranchDate(
    String branchCode,
  ) {
    return _get(CorpBankGuaranteeApiConst.branchDateApi(branchCode));
  }

  /// BG #41.
  Future<ResponseHandler<Map<String, dynamic>>> fetchMeParty() {
    return _get(CorpBankGuaranteeApiConst.mePartyApi);
  }

  /// BG #42.
  Future<ResponseHandler<Map<String, dynamic>>> fetchPartyRelations() {
    return _get(CorpBankGuaranteeApiConst.partyRelationsApi);
  }
}
