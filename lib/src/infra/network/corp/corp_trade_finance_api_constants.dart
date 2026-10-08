/// Trade Finance — Letter of Credit endpoint paths (corporate user).
///
/// Every path here was taken from the two pre-sales captures:
///  - `LC_inititation and amendments.har`   → referenced as **H1 #n**
///  - `LC_inititation and amendments02.har` → referenced as **H2 #n**
///
/// Paths marked **NOT CAPTURED** were not exercised successfully in either
/// capture and follow the digx-ui convention of the neighbouring calls.
/// Re-verify those against a fresh capture before relying on them.
///
/// Host, auth, `X-Target-Unit` and the `locale` query parameter are shared
/// with the rest of the app through `ObdxDioClient` / `ObdxApiUtils`.
class CorpTradeFinanceApiConst {
  CorpTradeFinanceApiConst._();

  static const String _base = '/digx-tradefinance/tradefinance/v1';

  /// Every trade-finance call in the capture sends this.
  static const String conventional = 'CONVENTIONAL';

  // ── Letter of Credit ─────────────────────────────────────────────────

  /// `GET` list — H1 #46 (Import), H2 #138 (Export), H1 #138 (amendable).
  /// Query: `lcType`, `partyIds`, `transactionType`, optional `lcStatus`,
  /// `isAmendable`.
  ///
  /// `POST` create — H1 #71 (draft, `state: DRAFT`, returns 201 + new id).
  /// Final submit (`state: INITIATED`) is **NOT CAPTURED** — see
  /// `CorpTradeFinanceRepository.submitInitiation`.
  static const String letterOfCreditsApi = '$_base/letterofcredits';

  /// `GET` detail — H1 #48, H1 #141. `PUT` draft update — H1 #74..#79.
  /// `DELETE` draft — H1 #80.
  static String letterOfCreditApi(String id) =>
      '$_base/letterofcredits/${Uri.encodeComponent(id)}';

  /// Saved drafts — H1 #90 (`autoSaved=true` variant H1 #41).
  static const String draftsApi = '$_base/letterofcredits/drafts';

  /// One saved draft in full — OBDX spec `LetterOfCredit.readDraft`.
  static String draftApi(String id) =>
      '$draftsApi/${Uri.encodeComponent(id)}';

  /// Saved templates — H1 #37 (`transactionType=CONVENTIONAL`), OBDX spec
  /// `LetterOfCredit.listTemplates`.
  static const String templatesApi = '$_base/letterofcredits/templates';

  /// One template in full — OBDX spec `LetterOfCredit.readTemplate`.
  static String templateApi(String id) =>
      '$templatesApi/${Uri.encodeComponent(id)}';

  /// Charge preview for a new LC — H1 #121 (400 on pre-sales: the fresh
  /// web flow left `partyId` empty, DIGX_LC_042).
  static const String chargesApi = '$_base/letterofcredits/charges';

  /// Amendment submit — H1 #204. The request body is from the capture; the
  /// call itself returned 401 (session had expired), so the success
  /// response shape is **NOT CAPTURED**.
  static String amendmentsApi(String lcId) =>
      '$_base/letterofcredits/${Uri.encodeComponent(lcId)}/amendments';

  /// Amendment charge preview — H1 #177 (400 DIGX_PROD_DEF_0000 on pre-sales).
  static String amendmentChargesApi(String lcId) =>
      '${amendmentsApi(lcId)}/charges';

  // ── Export LC ────────────────────────────────────────────────────────

  /// Export amendments awaiting beneficiary acceptance — H2 #157
  /// (`type=EXPORT&partyIds=&transactionType=CONVENTIONAL`).
  static const String amendmentListApi = '$_base/letterofcredits/amendments';

  /// Accept / reject one export amendment. **NOT CAPTURED** — follows the
  /// `letterofcredits/{id}/amendments` resource of H1 #204.
  static String amendmentApi(String lcId, String amendmentId) =>
      '${amendmentsApi(lcId)}/${Uri.encodeComponent(amendmentId)}';

  /// Transfer an Export LC to a second beneficiary. **NOT CAPTURED** — the
  /// captures stop at the transferable list (H2 #202, `transferrable=true`
  /// on [letterOfCreditsApi]).
  static String transfersApi(String lcId) =>
      '$_base/letterofcredits/${Uri.encodeComponent(lcId)}/transfers';

  // ── Export Bills ─────────────────────────────────────────────────────

  /// `GET` bill list — `partyIds` + a `q` criteria filter (billType,
  /// transactionType, status, billReferenceNo, ccy, drawee, billAmtFrom /
  /// To, billDateFrom / To). From the OBDX web client's own bill screens in
  /// the Export LC captures; the call itself returned 400 there (the
  /// host's trade back office was unreachable), so the response has not
  /// been seen.
  ///
  /// Also the View LC Bills tab: bills under an LC — H4 #51 (`q` criteria:
  /// billType, lcRefNo, transactionType). 400 on pre-sales.
  static const String billsApi = '$_base/bills';

  /// `GET` one bill — answers `bill`. Same source as [billsApi].
  static String billApi(String billReferenceNo) =>
      '$_base/bills/${Uri.encodeComponent(billReferenceNo)}';

  // ── Products & configuration ─────────────────────────────────────────

  /// LC products — H1 #51.
  static const String productsApi = '$_base/tradeproducts/letterofcredits';

  /// Product documents + clauses — H1 #159.
  static String productDocumentsApi(String productId) =>
      '$productsApi/${Uri.encodeComponent(productId)}/documents';

  /// Trade configuration (`TRADE_BRANCH_CODE`, walk-in customer) — H1 #44.
  static const String configurationsApi = '$_base/configurations';

  // ── Lookups ──────────────────────────────────────────────────────────

  /// `tradeEnumerations/{name}` — currencies H1 #42 (empty on pre-sales),
  /// country H1 #142, confirmationInstruction H1 #115,
  /// confirmationParty H1 #117.
  static String enumerationApi(String name) =>
      '$_base/tradeEnumerations/$name';

  static const String enumCurrencies = 'currencies';
  static const String enumCountry = 'country';
  static const String enumConfirmationInstruction = 'confirmationInstruction';
  static const String enumConfirmationParty = 'confirmationParty';

  /// Goods master — H1 #102 (`queryParams` criteria on transactionType).
  static const String goodsApi = '$_base/tradeGoods';

  /// Incoterms — H1 #106.
  static const String incotermsApi = '$_base/tradeIncoterms';

  /// Document master — H1 #105.
  static const String tradeDocumentsApi = '$_base/tradeDocument';

  /// Standard additional conditions — H1 #104.
  static const String additionalConditionsApi =
      '$_base/letterofcredits/additionalConditions';

  /// SWIFT/BIC lookup — H1 #143 (`q` criteria `swiftCode EQUALS`).
  static const String bicCodesApi = '$_base/tradeBicCodes';

  /// Maintained LC beneficiaries — H1 #99, H3 #49
  /// (`transactionType=LETTEROFCREDIT`; empty for the captured party).
  static const String beneficiariesApi = '$_base/beneficiaries';

  // ── Initiate LC sections (`LC_inititation complete flow.har` → H3 #n) ──

  /// Insurance policies of the party — H3 #72 (`partyId=`).
  static const String insurancePoliciesApi = '$_base/insurancePolicies';

  /// Party-maintained additional conditions — H3 #63 (`partyId=`).
  static const String additionalConditionMaintenanceApi =
      '$_base/additionalConditionMaintenance';

  /// Attachment document categories — H3 #75.
  static const String documentCategoriesApi =
      '$_base/documentcontent/documentcategories';

  /// CASA accounts — H3 #67 (linkages) and H3 #73 with
  /// `taskCode=[chargeAccountTaskCode]` (charge accounts).
  static const String accountsApi = '/digx-common/dda/v1/demandDeposit';
  static const String chargeAccountTaskCode = 'TF_AF_CLC';

  /// `transactionType` the beneficiary maintenance is filtered on (H3 #49).
  static const String beneficiaryTransactionType = 'LETTEROFCREDIT';

  // ── Initiate LC, per section (one capture per section → H5) ─────────
  //
  // `create lcdetails screen api.har`, `goods and shipment api.har`,
  // `document and condition api.har`, `linkage api.har`,
  // `instructions api.har`, `insurance api.har`,
  // `charges commission and taxes api.har`, `attachment api.har`.

  /// The logged-in party — H5 LC Details / Insurance (`me/party`).
  static const String mePartyApi = '/digx-common/user/v1/me/party';

  /// Related parties (other applicants the user may act for) — H5 LC
  /// Details (`partyToPartyRelationship`, empty in the capture).
  static const String partyRelationsApi =
      '/digx-common/user/v1/me/party/relations';

  /// Host business date of a branch — H5 LC Details
  /// (`branchdate/{TRADE_BRANCH_CODE}`; 400 DIGX_DT_001 on pre-sales).
  static String branchDateApi(String branchCode) =>
      '$_base/branchdate/${Uri.encodeComponent(branchCode)}';

  /// Term deposits for linkages — H5 Linkages (500 on pre-sales).
  static const String corporateDepositApi = '$_base/corporateDeposit';

  /// Standard customer instructions — H5 Instructions (`queryParams`
  /// criteria transactionType = LETTER_OF_CREDIT, productCode; 500 on
  /// pre-sales).
  static const String customerInstructionsApi = '$_base/customerInstructions';
  static const String customerInstructionTransactionType = 'LETTER_OF_CREDIT';

  /// Attachment upload — `upload api.har`: multipart `POST` with query
  /// `fileName=<name><index>` and the form fields `file`, `transactionType`
  /// (`LC`), `moduleIdentifier` (`LC_DOC_ATTACHMENT`), `fileCount`,
  /// `documentTypeId`, `documentCategoryId`, `comment`. The capture
  /// answered DIGX_CM_0005 (file too large), so the success body has not
  /// been seen.
  static const String contentUploadApi = '/digx-common/content/v1/contents';
  static const String uploadTransactionType = 'LC';
  static const String uploadModuleIdentifier = 'LC_DOC_ATTACHMENT';

  // ── View LC tabs (`view_LC_details.har` → H4 #n) ─────────────────────

  /// Shipping guarantees linked to an LC — H4 #53 (`q` criteria:
  /// islclinkage, lcid, type).
  static const String shippingGuaranteesApi = '$_base/shippingGuarantees';

  /// Charges booked on an LC — H4 #56 (OBDX spec `listCharges`; 400 on
  /// pre-sales).
  static String lcChargesApi(String lcId) =>
      '${letterOfCreditApi(lcId)}/charges';

  /// Bank branches (id → name) for the LC branch — H4 #26.
  static const String branchesApi =
      '/digx-common/location/v1/locations/country/all/city/all/branchCode';

  // ── UI component names (authorization set from `me/components`) ──────

  static const String componentViewImport = 'view-import-lc';
  static const String componentViewExport = 'view-export-lc';
  static const String componentInitiate = 'initiate-letter-of-credit';
  static const String componentAmend = 'amend-lc';
  static const String componentAmendmentAcceptance =
      'initiate-customer-acceptance';
  static const String componentInitiateTransfer = 'lc-transfer-multiple-init';
  static const String componentAmendTransfer = 'view-amend-transfer-lc';
}
