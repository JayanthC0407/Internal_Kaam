/// Trade Finance — Bank Guarantee endpoint paths (corporate user).
///
/// Every path here comes from `inward_bank_guarantee_api.har`, referenced
/// as **BG #n** (the HAR entry index). Where the call itself was not made
/// in the capture, the path is read from the OBDX web component's own
/// service model, which the capture also downloaded (the `loader.js` of
/// `components/guarantee/…`), and is marked **FROM COMPONENT**.
///
/// Paths marked **NOT CAPTURED** appear in neither: the web client reaches
/// them through components (`review-guarantee-acceptance`,
/// `view-lodge-claim`) that were not opened in the capture. They follow the
/// digx-ui convention of the neighbouring calls — re-verify them against a
/// fresh capture before relying on them.
///
/// Note on the capture itself: every guarantee *list* call (BG #44, #51,
/// #76, #84) answered 400 `DIGX_PROD_DEF_0000` — the host's trade back
/// office was unreachable (`JMSEndpoint`). The response field names the
/// models read are therefore taken from the web components' mapping code,
/// not from a live response.
///
/// Host, auth, `X-Target-Unit` and the `locale` query parameter are shared
/// with the rest of the app through `ObdxDioClient` / `ObdxApiUtils`.
class CorpBankGuaranteeApiConst {
  CorpBankGuaranteeApiConst._();

  static const String _base = '/digx-tradefinance/tradefinance/v1';

  // ── Bank guarantees ──────────────────────────────────────────────────

  /// `GET` list — BG #44 (conventional), BG #51 (Islamic), BG #76 / #84
  /// (`isClaimable=true`, the Lodge Claim search). Answers
  /// `bankGuaranteeDTO[]`.
  ///
  /// Query (from the component's `bankguaranteesget`): `bgNumber`,
  /// `custRefNo`, `beneName`, `bgStatus`, `fromAmount`, `toAmount`,
  /// `currency`, `issueDatefrom`, `issueDateto`, `expiryDatefrom`,
  /// `expiryDateto`, `partyId`, `applicantName`, `lcId`, `issuingBank`,
  /// `issuingBankRefNo`, `transactionType` (`INWARD`/`OUTWARD`),
  /// `isClaimable`, `cancellationAllowed`, `isAmendable`, `categoryType`
  /// (`CONVENTIONAL`/`ISLAMIC`), `dashboardDetails`, `standByLC` (`Y`/`N`).
  ///
  /// With `media` + `mediaFormat` the same call downloads the list as a
  /// PDF or CSV (component `bankguaranteesgetdownloadfile`).
  static const String bankGuaranteesApi = '$_base/bankguarantees';

  /// `GET` one guarantee — FROM COMPONENT (`bankguaranteesbankGuaranteeIdget`,
  /// query `categoryType`, `versionNo`). Answers `bankGuarantee`.
  static String bankGuaranteeApi(String id) =>
      '$_base/bankguarantees/${Uri.encodeComponent(id)}';

  // ── Amendments awaiting acceptance ───────────────────────────────────

  /// `GET` — BG #62 / #63 (conventional, with and without `partyId`),
  /// BG #67 (Islamic). Query `type=INWARD`, `categoryType`, optional
  /// `partyId`, `bankGuaranteeId`, `applicantName`, `beneName`. Answers
  /// `bankGuaranteeAmendmentDTOs[]`.
  static const String amendmentsApi = '$_base/bankguarantees/amendments';

  /// `GET` one amendment — FROM COMPONENT
  /// (`bankguaranteesbankGuaranteeIdamendmentsamendmentIdget`, query
  /// `amendStatus`, `authStatus`, `categoryType`). Answers
  /// `bankGuaranteeAmendment`.
  ///
  /// `PUT` accept / reject — **NOT CAPTURED**: the web client sends it from
  /// `customer-acceptance/review-guarantee-acceptance`, which the capture
  /// stops short of. Same resource as the LC equivalent
  /// (`letterofcredits/{id}/amendments/{amendmentId}`).
  static String amendmentApi(String bankGuaranteeId, String amendmentId) =>
      '$_base/bankguarantees/${Uri.encodeComponent(bankGuaranteeId)}'
      '/amendments/${Uri.encodeComponent(amendmentId)}';

  // ── Claims ───────────────────────────────────────────────────────────

  /// `POST` lodge a claim — **NOT CAPTURED**: the web client sends it from
  /// `guarantee/view-lodge-claim`, which the capture does not open.
  static String claimsApi(String bankGuaranteeId) =>
      '$_base/bankguarantees/${Uri.encodeComponent(bankGuaranteeId)}/claims';

  // ── Lookups & configuration ──────────────────────────────────────────

  /// `tradeEnumerations/{name}` — currencies BG #39 (empty on pre-sales);
  /// demand indicator types FROM COMPONENT (`claim-details`).
  static String enumerationApi(String name) =>
      '$_base/tradeEnumerations/$name';

  static const String enumCurrencies = 'currencies';
  static const String enumDemandIndicatorTypes = 'demandIndicatorTypes';

  /// Trade configuration (`TRADE_BRANCH_CODE`) — BG #69.
  static const String configurationsApi = '$_base/configurations';

  /// Host business date of a branch — BG #75 (400 `DIGX_DT_001` on
  /// pre-sales; the screens fall back to today).
  static String branchDateApi(String branchCode) =>
      '$_base/branchdate/${Uri.encodeComponent(branchCode)}';

  /// The logged-in party — BG #41.
  static const String mePartyApi = '/digx-common/user/v1/me/party';

  /// Related parties — BG #42 (`partyToPartyRelationship`, empty in the
  /// capture). Feeds the "All parties" selector.
  static const String partyRelationsApi =
      '/digx-common/user/v1/me/party/relations';

  // ── Request values ───────────────────────────────────────────────────

  static const String inward = 'INWARD';
  static const String outward = 'OUTWARD';

  // ── UI component names (authorization set from `me/components`) ──────
  //
  // The web menu opens these components (BG #37, #46, #52, #64, #68, #77).
  // Whether the bank's `me/components` set lists them by these names has
  // not been seen in a capture — see `LcPermissions` for how that is
  // handled.

  static const String componentInwardList = 'inward-guarantee-list';
  static const String componentInwardListIslamic =
      'inward-guarantee-list-islamic';
  static const String componentInwardAmendment = 'inward-guarantee-amendment';
  static const String componentInwardAmendmentIslamic =
      'inward-guarantee-amendment-islamic';
  static const String componentLodgeClaims = 'lodge-claims';
  static const String componentLodgeClaimsIslamic = 'lodge-claims-islamic';

  static const Set<String> allComponents = {
    componentInwardList,
    componentInwardListIslamic,
    componentInwardAmendment,
    componentInwardAmendmentIslamic,
    componentLodgeClaims,
    componentLodgeClaimsIslamic,
  };
}
