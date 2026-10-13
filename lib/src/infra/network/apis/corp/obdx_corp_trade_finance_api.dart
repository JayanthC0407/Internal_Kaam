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

  /// `GET …/letterofcredits` with free search criteria — OBDX spec
  /// `LetterOfCredit.list` (`lcNumber`, `beneName`, `applicantName`,
  /// `fromAmount`/`toAmount`, `currency`, `issueDatefrom`/`to`,
  /// `expiryDatefrom`/`to`, `lcStatus`, `lcType`, `partyIds`…). Used by the
  /// Copy & Initiate and Back to Back LC searches.
  Future<ResponseHandler<Map<String, dynamic>>> searchLetterOfCredits(
    Map<String, dynamic> query,
  ) {
    return _get(CorpTradeFinanceApiConst.letterOfCreditsApi, {
      ...query,
      'transactionType': _conventional,
    });
  }

  /// `GET …/letterofcredits` with `media` / `mediaFormat` — the LC list as
  /// a file (`application/pdf` + `pdf`, or `text/csv` + `csv`), as the View
  /// Export LC capture downloads it. Returns the file's bytes.
  Future<ResponseHandler<List<int>>> downloadLetterOfCredits(
    Map<String, dynamic> query, {
    required String media,
    required String mediaFormat,
  }) async {
    try {
      final response = await dio.get<List<int>>(
        ObdxApiUtils.appendLocaleQuery(
          CorpTradeFinanceApiConst.letterOfCreditsApi,
        ),
        queryParameters: {
          ...query,
          'media': media,
          'mediaFormat': mediaFormat,
          'transactionType': _conventional,
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

  /// `GET …/bills?partyIds=…&q=…` — the bill list for a ready query
  /// (Export Bills search). [fetchBills] is the bills under one LC.
  Future<ResponseHandler<Map<String, dynamic>>> searchBills(
    Map<String, dynamic> query,
  ) {
    return _get(CorpTradeFinanceApiConst.billsApi, query);
  }

  /// `GET …/bills/{billReferenceNo}` — one bill.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBill(String id) {
    return _get(
      CorpTradeFinanceApiConst.billApi(id),
      {'transactionType': _conventional},
    );
  }

  /// The bill list as a file. The web client downloads it from the same
  /// call; the `media` / `mediaFormat` pair is the LC list's (captured),
  /// assumed to apply here too.
  Future<ResponseHandler<List<int>>> downloadBills(
    Map<String, dynamic> query, {
    required String media,
    required String mediaFormat,
  }) async {
    try {
      final response = await dio.get<List<int>>(
        ObdxApiUtils.appendLocaleQuery(CorpTradeFinanceApiConst.billsApi),
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

  /// `GET …/letterofcredits/templates` — H1 #37.
  Future<ResponseHandler<Map<String, dynamic>>> fetchTemplates() {
    return _get(CorpTradeFinanceApiConst.templatesApi, {
      'transactionType': _conventional,
    });
  }

  /// `GET …/letterofcredits/templates/{id}` — OBDX spec `readTemplate`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchTemplate(String id) {
    return _get(CorpTradeFinanceApiConst.templateApi(id));
  }

  /// `GET …/letterofcredits/drafts/{id}` — OBDX spec `readDraft`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDraft(String id) {
    return _get(CorpTradeFinanceApiConst.draftApi(id));
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

  // ── Initiate LC sections (H3 = `LC_inititation complete flow.har`) ──

  /// Maintained beneficiaries — H3 #49.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBeneficiaries() {
    return _get(CorpTradeFinanceApiConst.beneficiariesApi, {
      'transactionType': CorpTradeFinanceApiConst.beneficiaryTransactionType,
    });
  }

  /// Document master — H3 #58.
  Future<ResponseHandler<Map<String, dynamic>>> fetchTradeDocuments() {
    return _get(CorpTradeFinanceApiConst.tradeDocumentsApi);
  }

  /// Party-maintained additional conditions — H3 #63.
  Future<ResponseHandler<Map<String, dynamic>>> fetchMaintainedConditions(
    String? partyId,
  ) {
    return _get(CorpTradeFinanceApiConst.additionalConditionMaintenanceApi, {
      if (partyId != null && partyId.isNotEmpty) 'partyId': partyId,
    });
  }

  /// Insurance policies — H3 #72.
  Future<ResponseHandler<Map<String, dynamic>>> fetchInsurancePolicies(
    String? partyId,
  ) {
    return _get(CorpTradeFinanceApiConst.insurancePoliciesApi, {
      if (partyId != null && partyId.isNotEmpty) 'partyId': partyId,
    });
  }

  /// CASA accounts — H3 #67, or the LC charge accounts (H3 #73) when
  /// [chargeAccounts] is set.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccounts({
    bool chargeAccounts = false,
  }) {
    return _get(CorpTradeFinanceApiConst.accountsApi, {
      if (chargeAccounts)
        'taskCode': CorpTradeFinanceApiConst.chargeAccountTaskCode,
    });
  }

  /// Attachment categories — H3 #75.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDocumentCategories() {
    return _get(CorpTradeFinanceApiConst.documentCategoriesApi);
  }

  // ── Initiate LC, per section (H5 captures) ─────────────────────────

  /// `me/party` — H5 LC Details / Insurance.
  Future<ResponseHandler<Map<String, dynamic>>> fetchMeParty() {
    return _get(CorpTradeFinanceApiConst.mePartyApi);
  }

  /// `me/party/relations` — H5 LC Details.
  Future<ResponseHandler<Map<String, dynamic>>> fetchPartyRelations() {
    return _get(CorpTradeFinanceApiConst.partyRelationsApi);
  }

  /// `branchdate/{branchCode}` — H5 LC Details.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBranchDate(
    String branchCode,
  ) {
    return _get(CorpTradeFinanceApiConst.branchDateApi(branchCode));
  }

  /// `corporateDeposit` — H5 Linkages (term deposits).
  Future<ResponseHandler<Map<String, dynamic>>> fetchCorporateDeposits() {
    return _get(CorpTradeFinanceApiConst.corporateDepositApi);
  }

  /// `customerInstructions` — H5 Instructions. [productCode] goes out as
  /// `null` when no product is chosen yet, as the web sends it.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCustomerInstructions(
    String? productCode,
  ) {
    return _get(CorpTradeFinanceApiConst.customerInstructionsApi, {
      'queryParams': _criteria([
        {
          'operand': 'transactionType',
          'operator': 'EQUALS',
          'value': [CorpTradeFinanceApiConst.customerInstructionTransactionType],
        },
        {
          'operand': 'productCode',
          'operator': 'EQUALS',
          'value': [productCode],
        },
      ]),
    });
  }

  /// Uploads one attachment — `upload api.har` (see
  /// [CorpTradeFinanceApiConst.contentUploadApi]). [index] is the file's
  /// position in the batch, appended to `fileName` as the web does
  /// (`main.dart.js0`).
  Future<ResponseHandler<Map<String, dynamic>>> uploadContent({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    required int index,
    required int fileCount,
    String? documentTypeId,
    String? documentCategoryId,
    String comment = '',
  }) {
    return _run(() => dio.post(
          ObdxApiUtils.appendLocaleQuery(
            CorpTradeFinanceApiConst.contentUploadApi,
          ),
          queryParameters: {'fileName': '$fileName$index'},
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(
              bytes,
              filename: fileName,
              contentType: DioMediaType.parse(mimeType),
            ),
            'transactionType': CorpTradeFinanceApiConst.uploadTransactionType,
            'moduleIdentifier': CorpTradeFinanceApiConst.uploadModuleIdentifier,
            'fileCount': '$fileCount',
            'documentTypeId': documentTypeId ?? '',
            'documentCategoryId': documentCategoryId ?? '',
            'comment': comment,
          }),
          options: Options(contentType: 'multipart/form-data'),
        ));
  }

  // ── View LC tabs (H4 = `view_LC_details.har`) ─────────────────────

  /// Amendments of one LC — H4 #49.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLcAmendments(
    String lcId,
  ) {
    return _get(CorpTradeFinanceApiConst.amendmentsApi(lcId), {
      'transactionType': _conventional,
    });
  }

  /// Bills drawn under an LC — H4 #51. [billType] is `IMPORT` / `EXPORT`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBills({
    required String lcId,
    required String billType,
  }) {
    return _get(CorpTradeFinanceApiConst.billsApi, {
      'q': _criteria([
        {
          'operand': 'billType',
          'operator': 'EQUALS',
          'value': [billType],
        },
        {
          'operand': 'lcRefNo',
          'operator': 'EQUALS',
          'value': [lcId],
        },
        {
          'operand': 'transactionType',
          'operator': 'EQUALS',
          'value': [_conventional],
        },
      ]),
    });
  }

  /// Shipping guarantees linked to an LC — H4 #53.
  Future<ResponseHandler<Map<String, dynamic>>> fetchShippingGuarantees(
    String lcId,
  ) {
    return _get(CorpTradeFinanceApiConst.shippingGuaranteesApi, {
      'q': _criteria([
        {
          'operand': 'islclinkage',
          'operator': 'EQUALS',
          'value': ['Y'],
        },
        {
          'operand': 'lcid',
          'operator': 'EQUALS',
          'value': [lcId],
        },
        {
          'operand': 'type',
          'operator': 'ENUM',
          'value': [_conventional],
        },
      ]),
    });
  }

  /// Charges booked on an LC — H4 #56.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLcCharges(String lcId) {
    return _get(CorpTradeFinanceApiConst.lcChargesApi(lcId), {
      'transactionType': _conventional,
    });
  }

  /// Bank branches — H4 #26.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBranches() {
    return _get(CorpTradeFinanceApiConst.branchesApi);
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
