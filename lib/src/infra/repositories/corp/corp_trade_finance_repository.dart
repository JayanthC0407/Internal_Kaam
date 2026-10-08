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
    final result = await _api.searchBills(query);
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

  // ── Initiate LC, per section (H5 = one capture per section) ────────

  Future<T> _soft<T>(
    ResponseHandler<Map<String, dynamic>> result,
    T Function(Map<String, dynamic>) parse,
    T fallback, {
    List<String>? warnings,
    String? warning,
  }) async {
    final parsed = await parseBody(result, parse);
    if (parsed is Success<T>) return parsed.data ?? fallback;
    if (warnings != null && warning != null) warnings.add(warning);
    return fallback;
  }

  /// The logged-in party id from `me/party` (H5 LC Details / Insurance),
  /// or [fallback] when the call fails.
  Future<String?> fetchMePartyId({String? fallback}) async {
    final result = await _api.fetchMeParty();
    final id = await _soft<String?>(
      result,
      (b) => TfJson.str(TfJson.map(TfJson.map(b['party'])['id'])['value']),
      null,
    );
    return id ?? fallback;
  }

  /// 01 LC Details — beneficiaries, related parties and the branch date.
  Future<LcDetailsSectionData> fetchLcDetailsSection({
    String? branchCode,
  }) async {
    final warnings = <String>[];
    final results = await Future.wait([
      _api.fetchBeneficiaries(),
      _api.fetchPartyRelations(),
      if (branchCode != null) _api.fetchBranchDate(branchCode),
    ]);
    return LcDetailsSectionData(
      beneficiaries: await _soft(
        results[0],
        LcBeneficiary.listFromPayload,
        const <LcBeneficiary>[],
        warnings: warnings,
        warning: 'Maintained beneficiaries could not be loaded.',
      ),
      relatedParties: await _soft(
        results[1],
        LcRelatedParty.listFromPayload,
        const <LcRelatedParty>[],
      ),
      // DIGX_DT_001 on pre-sales — the date then falls back to today.
      branchDate: results.length > 2
          ? await _soft<DateTime?>(results[2], LcBranchDate.fromPayload, null)
          : null,
      warnings: warnings,
    );
  }

  /// 03 Documents & Conditions — document master and party conditions.
  Future<LcDocumentsSectionData> fetchDocumentsSection({
    String? partyId,
  }) async {
    final warnings = <String>[];
    final results = await Future.wait([
      _api.fetchTradeDocuments(),
      _api.fetchMaintainedConditions(partyId),
    ]);
    return LcDocumentsSectionData(
      tradeDocuments: await _soft(
        results[0],
        LcDocument.listFromPayload,
        const <LcDocument>[],
        warnings: warnings,
        warning: 'The document list could not be loaded.',
      ),
      maintainedConditions: await _soft(
        results[1],
        (b) => TradeCode.listFrom(b['list']),
        const <TradeCode>[],
      ),
      warnings: warnings,
    );
  }

  /// 04 Linkages — term deposits, currencies and CASA accounts.
  Future<LcLinkagesSectionData> fetchLinkagesSection() async {
    final warnings = <String>[];
    final results = await Future.wait([
      _api.fetchCorporateDeposits(),
      _api.fetchEnumeration(CorpTradeFinanceApiConst.enumCurrencies),
      _api.fetchAccounts(),
    ]);
    final deposits = await _soft(
      results[0],
      (b) => LcAccount.listFromPayload(b, termDeposits: true),
      const <LcAccount>[],
      warnings: warnings,
      // 500 DIGX_CO_0003 on pre-sales.
      warning: 'Term deposits are not available right now.',
    );
    final casa = await _soft(
      results[2],
      LcAccount.listFromPayload,
      const <LcAccount>[],
      warnings: warnings,
      warning: 'Current and savings accounts could not be loaded.',
    );
    return LcLinkagesSectionData(
      accounts: [...casa, ...deposits],
      currencies: await _soft(
        results[1],
        TradeCode.fromEnumeration,
        const <TradeCode>[],
      ),
      warnings: warnings,
    );
  }

  /// 05 Instructions — confirmation options, parties and the standard
  /// instructions for [productCode].
  Future<LcInstructionsSectionData> fetchInstructionsSection({
    String? productCode,
  }) async {
    final warnings = <String>[];
    final results = await Future.wait([
      _api.fetchEnumeration(
        CorpTradeFinanceApiConst.enumConfirmationInstruction,
      ),
      _api.fetchEnumeration(CorpTradeFinanceApiConst.enumConfirmationParty),
      _api.fetchCustomerInstructions(productCode),
    ]);
    return LcInstructionsSectionData(
      confirmationInstructions: await _soft(
        results[0],
        TradeCode.fromEnumeration,
        const <TradeCode>[],
      ),
      confirmationParties: await _soft(
        results[1],
        TradeCode.fromEnumeration,
        const <TradeCode>[],
      ),
      standardInstructions: await _soft(
        results[2],
        LcStandardInstructions.fromPayload,
        const <String>[],
        warnings: warnings,
        // 500 DIGX_CO_0003 on pre-sales.
        warning: 'The standard instructions could not be loaded.',
      ),
      warnings: warnings,
    );
  }

  /// 06 Insurance — `me/party`, then the party's policies (H5 Insurance).
  Future<ResponseHandler<List<LcInsurancePolicy>>> fetchInsuranceSection({
    String? fallbackPartyId,
  }) async {
    final partyId = await fetchMePartyId(fallback: fallbackPartyId);
    final result = await _api.fetchInsurancePolicies(partyId);
    return parseBody(result, LcInsurancePolicy.listFromPayload);
  }

  /// 07 Charges — the accounts allowed for LC charges (`taskCode`).
  Future<ResponseHandler<List<LcAccount>>> fetchChargeAccounts() async {
    final result = await _api.fetchAccounts(chargeAccounts: true);
    return parseBody(result, LcAccount.listFromPayload);
  }

  /// 08 Attachments — document categories (H5 Attachments).
  Future<ResponseHandler<List<LcDocumentCategory>>> fetchDocumentCategories()
      async {
    final result = await _api.fetchDocumentCategories();
    return parseBody(result, LcDocumentCategory.listFromPayload);
  }

  /// Saves the form as a template — `template save api.har`: the
  /// Attachments section's Save posts the full LC body to
  /// `POST …/letterofcredits` with `state: TEMPLATE`, `name` and
  /// `visibility`. The capture answered 400 (pre-sales field-validation
  /// setup), so success is read like the draft create (H1 #71: 201 +
  /// `letterOfCredit.id`).
  Future<ResponseHandler<String>> saveTemplate(
    Map<String, dynamic> body,
  ) async {
    final result = await _api.createLetterOfCredit(body);
    return parseBody(
      result,
      (b) => CorpLetterOfCredit.fromDetailPayload(b)?.id ?? '',
      successCodes: _created,
    );
  }

  /// Uploads [attachment] (`upload api.har`); returns its content id.
  /// The success body was not captured (the capture failed with
  /// DIGX_CM_0005), so the id is read from the usual OBDX content fields;
  /// an answer without one still counts as uploaded.
  Future<ResponseHandler<String>> uploadAttachment(
    LcAttachment attachment, {
    required int index,
    required int fileCount,
  }) async {
    final result = await _api.uploadContent(
      bytes: attachment.bytes,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      index: index,
      fileCount: fileCount,
      documentTypeId: attachment.documentType,
      documentCategoryId: attachment.category,
    );
    return parseBody(
      result,
      (b) => LcAttachment.contentIdFrom(b) ?? '',
      successCodes: _created,
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
