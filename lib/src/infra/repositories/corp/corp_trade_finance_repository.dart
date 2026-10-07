import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_bill.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_trade_finance_api.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_trade_finance_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_repository_base.dart';

/// Letter of Credit repository — turns [ObdxCorpTradeFinanceApi] envelopes
/// into models, with OBDX's two failure shapes mapped by
/// [CorpRepositoryBase.parseBody].
class CorpTradeFinanceRepository extends CorpRepositoryBase {
  CorpTradeFinanceRepository({required ObdxCorpTradeFinanceApi api})
      : _api = api;

  final ObdxCorpTradeFinanceApi _api;

  // 201 Created — the draft create answers 201 (H1 #71).
  static const _created = {StatusCode.OK, 201};

  // ── Read ─────────────────────────────────────────────────────────────

  /// Import / Export LC list. [amendableOnly] narrows to active, amendable
  /// Import LCs — the list the Amend flow starts from (H1 #138).
  Future<ResponseHandler<List<CorpLetterOfCredit>>> fetchLetterOfCredits({
    required LcType lcType,
    String? partyId,
    bool amendableOnly = false,
  }) async {
    final result = await _api.fetchLetterOfCredits(
      lcType: lcType.apiValue,
      partyId: partyId,
      amendableOnly: amendableOnly,
      lcStatus: amendableOnly ? 'ACTIVE' : null,
    );
    return parseBody(
      result,
      (body) => CorpLetterOfCredit.listFromPayload(body, fallbackType: lcType),
    );
  }

  Future<ResponseHandler<CorpLetterOfCredit>> fetchLetterOfCredit(
    String id, {
    String? versionNo,
  }) async {
    final result = await _api.fetchLetterOfCredit(id, versionNo: versionNo);
    return parseBody(result, (body) {
      final lc = CorpLetterOfCredit.fromDetailPayload(body);
      if (lc == null) throw const FormatException('letterOfCredit missing');
      return lc;
    });
  }

  /// Free LC search (Copy & Initiate, Back to Back LC).
  Future<ResponseHandler<List<CorpLetterOfCredit>>> searchLetterOfCredits(
    LcSearchCriteria criteria, {
    String? partyId,
  }) async {
    final result = await _api.searchLetterOfCredits(
      criteria.toQuery(partyId: partyId),
    );
    return parseBody(
      result,
      (body) => CorpLetterOfCredit.listFromPayload(
        body,
        fallbackType: criteria.lcType,
      ),
    );
  }

  /// Export LC search (View Export LC) with a ready query — see
  /// `ExportLcSearch.toQuery`.
  Future<ResponseHandler<List<CorpLetterOfCredit>>> searchExportLetterOfCredits(
    Map<String, dynamic> query,
  ) async {
    final result = await _api.searchLetterOfCredits(query);
    return parseBody(
      result,
      (body) => CorpLetterOfCredit.listFromPayload(
        body,
        fallbackType: LcType.exportLc,
      ),
    );
  }

  /// The LC list for [query] as a PDF or CSV file.
  Future<ResponseHandler<List<int>>> downloadLetterOfCredits(
    Map<String, dynamic> query, {
    required String media,
    required String mediaFormat,
  }) {
    return _api.downloadLetterOfCredits(
      query,
      media: media,
      mediaFormat: mediaFormat,
    );
  }

  /// Export bills for a ready query — see `ExportBillSearch.toQuery`.
  Future<ResponseHandler<List<CorpExportBill>>> searchExportBills(
    Map<String, dynamic> query,
  ) async {
    final result = await _api.fetchBills(query);
    return parseBody(result, CorpExportBill.listFromPayload);
  }

  Future<ResponseHandler<CorpExportBill>> fetchExportBill(String id) async {
    final result = await _api.fetchBill(id);
    return parseBody(result, (body) {
      final bill = CorpExportBill.fromDetailPayload(body);
      if (bill == null) throw const FormatException('bill missing');
      return bill;
    });
  }

  Future<ResponseHandler<List<int>>> downloadExportBills(
    Map<String, dynamic> query, {
    required String media,
    required String mediaFormat,
  }) {
    return _api.downloadBills(query, media: media, mediaFormat: mediaFormat);
  }

  /// Saved templates (H1 #37 — `letterOfCreditDTOs`).
  Future<ResponseHandler<List<CorpLetterOfCredit>>> fetchTemplates() async {
    final result = await _api.fetchTemplates();
    return parseBody(result, CorpLetterOfCredit.listFromPayload);
  }

  /// One template in full, for prefilling the wizard.
  Future<ResponseHandler<CorpLetterOfCredit>> fetchTemplate(String id) async {
    final result = await _api.fetchTemplate(id);
    return parseBody(result, _detailOrThrow);
  }

  /// One draft in full, for continuing it in the wizard.
  Future<ResponseHandler<CorpLetterOfCredit>> fetchDraft(String id) async {
    final result = await _api.fetchDraft(id);
    return parseBody(result, _detailOrThrow);
  }

  static CorpLetterOfCredit _detailOrThrow(Map<String, dynamic> body) {
    final lc = CorpLetterOfCredit.fromDetailPayload(body);
    if (lc == null) throw const FormatException('letterOfCredit missing');
    return lc;
  }

  Future<ResponseHandler<List<CorpLetterOfCredit>>> fetchDrafts() async {
    final result = await _api.fetchDrafts();
    return parseBody(result, CorpLetterOfCredit.listFromPayload);
  }

  /// Every lookup the initiate form needs, fetched in parallel. A lookup
  /// that fails leaves its list empty instead of failing the form; only
  /// the product list is essential and is reported as a failure.
  Future<ResponseHandler<LcLookups>> fetchLookups() async {
    final results = await Future.wait([
      _api.fetchProducts(),
      _api.fetchEnumeration(CorpTradeFinanceApiConst.enumCurrencies),
      _api.fetchEnumeration(CorpTradeFinanceApiConst.enumCountry),
      _api.fetchEnumeration(
        CorpTradeFinanceApiConst.enumConfirmationInstruction,
      ),
      _api.fetchGoods(),
      _api.fetchIncoterms(),
      _api.fetchAdditionalConditions(),
      _api.fetchConfigurations(),
    ]);

    final products = await parseBody(results[0], LcProduct.listFromPayload);
    if (products is! Success<List<LcProduct>>) {
      return mapFailure(products);
    }

    Future<T> soft<T>(
      ResponseHandler<Map<String, dynamic>> r,
      T Function(Map<String, dynamic>) parse,
      T fallback,
    ) async {
      final parsed = await parseBody(r, parse);
      return parsed is Success<T> ? (parsed.data ?? fallback) : fallback;
    }

    return ResponseHandler.success(
      LcLookups(
        products: products.data ?? const [],
        currencies: await soft(results[1], TradeCode.fromEnumeration, const []),
        countries: await soft(results[2], TradeCode.fromEnumeration, const []),
        confirmationInstructions:
            await soft(results[3], TradeCode.fromEnumeration, const []),
        goods: await soft(
          results[4],
          (b) => TradeCode.listFrom(b['goods']),
          const <TradeCode>[],
        ),
        incoterms: await soft(
          results[5],
          (b) => TradeCode.listFrom(b['incotermList']),
          const <TradeCode>[],
        ),
        additionalConditions: await soft(
          results[6],
          (b) => TradeCode.listFrom(b['list']),
          const <TradeCode>[],
        ),
        configuration: await soft(
          results[7],
          TradeFinanceConfiguration.fromPayload,
          TradeFinanceConfiguration.empty,
        ),
      ),
      code: StatusCode.OK,
    );
  }

  Future<ResponseHandler<List<LcDocument>>> fetchProductDocuments(
    String productId,
  ) async {
    final result = await _api.fetchProductDocuments(productId);
    return parseBody(result, LcDocument.listFromPayload);
  }

  /// Reference data for the Initiate LC sections (H3 #49 #58 #63 #67 #70
  /// #72 #73 #75), fetched in parallel. Never fails: a lookup that fails
  /// leaves its list empty, so the form still opens.
  Future<LcInitiateSupport> fetchInitiateSupport({String? partyId}) async {
    final results = await Future.wait([
      _api.fetchBeneficiaries(),
      _api.fetchTradeDocuments(),
      _api.fetchInsurancePolicies(partyId),
      _api.fetchAccounts(chargeAccounts: true),
      _api.fetchAccounts(),
      _api.fetchDocumentCategories(),
      _api.fetchEnumeration(CorpTradeFinanceApiConst.enumConfirmationParty),
      _api.fetchMaintainedConditions(partyId),
    ]);

    Future<T> soft<T>(
      ResponseHandler<Map<String, dynamic>> r,
      T Function(Map<String, dynamic>) parse,
      T fallback,
    ) async {
      final parsed = await parseBody(r, parse);
      return parsed is Success<T> ? (parsed.data ?? fallback) : fallback;
    }

    return LcInitiateSupport(
      beneficiaries:
          await soft(results[0], LcBeneficiary.listFromPayload, const []),
      tradeDocuments:
          await soft(results[1], LcDocument.listFromPayload, const []),
      insurancePolicies:
          await soft(results[2], LcInsurancePolicy.listFromPayload, const []),
      chargeAccounts:
          await soft(results[3], LcAccount.listFromPayload, const []),
      linkageAccounts:
          await soft(results[4], LcAccount.listFromPayload, const []),
      documentCategories:
          await soft(results[5], LcDocumentCategory.listFromPayload, const []),
      confirmationParties:
          await soft(results[6], TradeCode.fromEnumeration, const []),
      maintainedConditions: await soft(
        results[7],
        (b) => TradeCode.listFrom(b['list']),
        const <TradeCode>[],
      ),
    );
  }

  // ── View LC tabs (H4 = `view_LC_details.har`) ─────────────────────

  /// Amendment history of one LC — H4 #49.
  Future<ResponseHandler<List<CorpLcAmendment>>> fetchLcAmendments(
    String lcId,
  ) async {
    final result = await _api.fetchLcAmendments(lcId);
    return parseBody(result, CorpLcAmendment.listFromPayload);
  }

  /// Bills drawn under an LC — H4 #51.
  Future<ResponseHandler<List<LcBill>>> fetchBills(
    String lcId,
    LcType lcType,
  ) async {
    final result = await _api.fetchBills(
      lcId: lcId,
      billType: lcType == LcType.exportLc ? 'EXPORT' : 'IMPORT',
    );
    return parseBody(result, LcBill.listFromPayload);
  }

  /// Shipping guarantees linked to an LC — H4 #53.
  Future<ResponseHandler<List<LcShippingGuarantee>>> fetchShippingGuarantees(
    String lcId,
  ) async {
    final result = await _api.fetchShippingGuarantees(lcId);
    return parseBody(result, LcShippingGuarantee.listFromPayload);
  }

  /// Charges booked on an LC — H4 #56. The response key is NOT CAPTURED
  /// (400 on pre-sales), so the usual names are tried in turn.
  Future<ResponseHandler<List<LcCharge>>> fetchLcCharges(String lcId) async {
    final result = await _api.fetchLcCharges(lcId);
    return parseBody(result, (body) {
      final root = TfJson.root(body);
      return LcCharge.listFrom(
        root['charges'] ?? root['lcChargesDTOs'] ?? root['chargesList'],
      );
    });
  }

  /// Branch id → name (H4 #26). Never fails: empty on error.
  Future<Map<String, String>> fetchBranchNames() async {
    final parsed =
        await parseBody(await _api.fetchBranches(), LcBranchNames.fromPayload);
    return parsed is Success<Map<String, String>>
        ? (parsed.data ?? const {})
        : const {};
  }

  /// `tradeEnumerations/confirmationParty` (H4 #34). Never fails.
  Future<List<TradeCode>> fetchConfirmationParties() async {
    final parsed = await parseBody(
      await _api.fetchEnumeration(
        CorpTradeFinanceApiConst.enumConfirmationParty,
      ),
      TradeCode.fromEnumeration,
    );
    return parsed is Success<List<TradeCode>>
        ? (parsed.data ?? const [])
        : const [];
  }

  /// Resolves a SWIFT code; success with `null` means "not found".
  Future<ResponseHandler<TradeBank?>> lookupBic(String swiftCode) async {
    final result = await _api.lookupBic(swiftCode.trim().toUpperCase());
    return parseBody<TradeBank?>(result, (body) {
      final banks = TradeBank.listFromPayload(body);
      return banks.isEmpty ? null : banks.first;
    });
  }

  // ── Export LC ────────────────────────────────────────────────────────

  /// Transferable Export LCs — H2 #202.
  Future<ResponseHandler<List<CorpLetterOfCredit>>> fetchTransferableLcs({
    String? partyId,
  }) async {
    final result = await _api.fetchTransferableLcs(partyId: partyId);
    return parseBody(
      result,
      (body) => CorpLetterOfCredit.listFromPayload(
        body,
        fallbackType: LcType.exportLc,
      ),
    );
  }

  /// Export amendments awaiting acceptance — H2 #157.
  Future<ResponseHandler<List<CorpLcAmendment>>> fetchExportAmendments({
    String? partyId,
  }) async {
    final result = await _api.fetchExportAmendments(partyId: partyId);
    return parseBody(result, CorpLcAmendment.listFromPayload);
  }

  Future<ResponseHandler<LcSubmitOutcome>> respondToAmendment(
    CorpLcAmendment amendment, {
    required bool accept,
    String? remarks,
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final result = await _api.respondToAmendment(
      amendment.lcId,
      amendment.id,
      amendment.toResponseJson(accept: accept, remarks: remarks),
      challengeResponseHeader: (challenge != null && otp != null)
          ? challenge.toChallengeResponseHeader(otp)
          : null,
    );
    return _parseSubmit(result);
  }

  Future<ResponseHandler<LcSubmitOutcome>> submitTransfer(
    String lcId,
    Map<String, dynamic> body, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final result = await _api.initiateTransfer(
      lcId,
      body,
      challengeResponseHeader: (challenge != null && otp != null)
          ? challenge.toChallengeResponseHeader(otp)
          : null,
    );
    return _parseSubmit(result);
  }

  // ── Drafts ───────────────────────────────────────────────────────────

  /// Creates (no [draftId]) or updates a draft. Returns the draft id.
  ///
  /// Create answers 201 with `letterOfCredit.id` (H1 #71); update answers
  /// 200 with no LC body (H1 #74), so the existing id is returned.
  Future<ResponseHandler<String>> saveDraft(
    Map<String, dynamic> body, {
    String? draftId,
  }) async {
    if (draftId != null) {
      final result = await _api.updateLetterOfCredit(draftId, body);
      return parseBody(result, (_) => draftId);
    }
    final result = await _api.createLetterOfCredit(body);
    return parseBody(
      result,
      (b) {
        final id = CorpLetterOfCredit.fromDetailPayload(b)?.id;
        if (id == null) throw const FormatException('draft id missing');
        return id;
      },
      successCodes: _created,
    );
  }

  /// H1 #80.
  Future<ResponseHandler<bool>> deleteDraft(String draftId) async {
    final result = await _api.deleteLetterOfCredit(draftId);
    return parseBody(result, (_) => true);
  }

  // ── Charges ──────────────────────────────────────────────────────────

  Future<ResponseHandler<List<LcCharge>>> previewCharges(
    Map<String, dynamic> body,
  ) async {
    final result = await _api.fetchCharges(body);
    return parseBody(result, _parseCharges, successCodes: _created);
  }

  Future<ResponseHandler<List<LcCharge>>> previewAmendmentCharges(
    String lcId,
    Map<String, dynamic> body,
  ) async {
    final result = await _api.fetchAmendmentCharges(lcId, body);
    return parseBody(result, _parseCharges, successCodes: _created);
  }

  /// Charge previews were rejected by the pre-sales host (H1 #121, #177),
  /// so the success shape is unconfirmed; this accepts either a top-level
  /// `charges[]` or one nested under `letterOfCredit`.
  static List<LcCharge> _parseCharges(Map<String, dynamic> body) {
    final nested = TfJson.map(body['letterOfCredit']);
    return LcCharge.listFrom(body['charges'] ?? nested['charges']);
  }

  // ── Submit ───────────────────────────────────────────────────────────

  /// Submits a new LC.
  ///
  /// NOT CAPTURED: the web flow in the captures never reached submit. This
  /// POSTs the full DTO to `…/letterofcredits` with `state: INITIATED`,
  /// `autoSaved: false` — the same endpoint and body shape as the captured
  /// draft create (H1 #71). Confirm with a capture of a completed
  /// initiation before release.
  Future<ResponseHandler<LcSubmitOutcome>> submitInitiation(
    Map<String, dynamic> body, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final result = await _api.createLetterOfCredit(
      body,
      challengeResponseHeader: (challenge != null && otp != null)
          ? challenge.toChallengeResponseHeader(otp)
          : null,
    );
    return _parseSubmit(result);
  }

  /// Submits an amendment — body and path from H1 #204.
  Future<ResponseHandler<LcSubmitOutcome>> submitAmendment(
    String lcId,
    Map<String, dynamic> body, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final result = await _api.submitAmendment(
      lcId,
      body,
      challengeResponseHeader: (challenge != null && otp != null)
          ? challenge.toChallengeResponseHeader(otp)
          : null,
    );
    return _parseSubmit(result);
  }

  /// 417 + `X-Challenge` → [LcAwaitingOtp]; 2xx without error → [LcSubmitted];
  /// everything else → mapped error (wrong OTP comes back as an ERROR
  /// message and surfaces as such).
  Future<ResponseHandler<LcSubmitOutcome>> _parseSubmit(
    ResponseHandler<Map<String, dynamic>> result,
  ) async {
    if (result is Success<Map<String, dynamic>> && result.data != null) {
      final wrapped = result.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);
      if (statusCode == ApiConst.expectationFailed) {
        // Header first; `status.referenceNumber` when CORS hides the
        // header on web — same fallback the payments flow uses.
        final challenge = ObdxChallenge.fromResponse(
          headers: wrapped['headers'],
          body: body,
        );
        if (challenge != null && challenge.referenceNo.isNotEmpty) {
          return ResponseHandler.success(
            LcAwaitingOtp(challenge),
            code: statusCode,
          );
        }
      }
    }
    return parseBody<LcSubmitOutcome>(
      result,
      LcSubmitted.fromBody,
      successCodes: _created,
    );
  }
}
