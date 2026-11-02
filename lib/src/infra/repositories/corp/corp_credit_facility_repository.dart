import 'package:ubci_bank/src/core/models/corp/credit_facility_models.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_credit_facility_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_repository_base.dart';

/// Facilities and the first liability they belong to.
class CfFacilities {
  const CfFacilities({required this.liability, required this.roots});

  final CfLiability liability;

  /// Main lines, each with its sub-facilities.
  final List<CfFacility> roots;

  List<CfFacility> get all => CfFacility.flatten(roots);
}

/// Credit Facility Management: parses [ObdxCorpCreditFacilityApi] answers.
/// Every screen asks for the liabilities first and uses only the first one,
/// as OBDX does (card §2).
class CorpCreditFacilityRepository extends CorpRepositoryBase {
  CorpCreditFacilityRepository({required ObdxCorpCreditFacilityApi api}) : _api = api;

  final ObdxCorpCreditFacilityApi _api;

  Future<ResponseHandler<CfLiability>> _liability({String? partyId}) async {
    final result = await parseBody(await _api.fetchLiabilities(partyId: partyId), CfLiability.firstFrom);
    if (result is Success<CfLiability?> && result.data != null) return ResponseHandler.success(result.data!, code: 200);
    if (result is Success<CfLiability?>) return ResponseHandler.error(200, null);
    return mapFailure(result);
  }

  /// Selected Party options, the filter's currencies and the Group
  /// Corporate line. Each call is best effort: Facility Summary still works
  /// without them.
  Future<CfLookups> fetchLookups({String? groupCorporateId}) async {
    final (party, relations, currencies, group) = await (
      _api.fetchParty(),
      _api.fetchPartyRelations(),
      _api.fetchCurrencies(),
      groupCorporateId == null
          ? Future.value(ResponseHandler<Map<String, dynamic>>.error(0, null))
          : _api.fetchGroupCorporate(groupCorporateId),
    ).wait;
    Map<String, dynamic> body(ResponseHandler<Map<String, dynamic>> r) =>
        r is Success<Map<String, dynamic>> && r.data != null ? ObdxApiUtils.asMap(r.data!['body']) : const {};
    final own = CfParty.own(body(party));
    final groupName = ObdxApiUtils.asMap(body(group)['groupCorporate'])['name'];
    return CfLookups(
      parties: [if (own != null) own, ...CfParty.related(body(relations))],
      currencies: CfLookups.currenciesFrom(body(currencies)),
      groupCorporate: groupCorporateId == null
          ? null
          : groupName == null
              ? groupCorporateId
              : '$groupCorporateId | $groupName',
    );
  }

  /// Facility Summary: `liabilities?partyId=` then the facilities with the
  /// same party (empty until a party is chosen, as in OBDX).
  Future<ResponseHandler<CfFacilities>> fetchFacilities(String partyId) async {
    final liability = await _liability(partyId: partyId);
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    final l = liability.data!;
    final list = await parseBody(
      await _api.fetchFacilities(l.id, partyId: partyId, branchCode: l.branch, currencyCode: cfCurrencyCode),
      CfFacility.listFromPayload,
    );
    if (list is! Success<List<CfFacility>>) return mapFailure(list);
    return ResponseHandler.success(CfFacilities(liability: l, roots: list.data ?? const []), code: 200);
  }

  /// Download: `liabilities` (no query), then the list as a PDF.
  Future<ResponseHandler<List<int>>> downloadFacilities(String partyId) async {
    final liability = await _liability();
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    final l = liability.data!;
    return _api.downloadFacilities(l.id, partyId: partyId, branchCode: l.branch, currencyCode: cfCurrencyCode);
  }

  /// Facility Details' Facility Name options: the user's own party.
  Future<ResponseHandler<CfFacilities>> fetchFacilityOptions(String userPartyId) async {
    final liability = await _liability();
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    final l = liability.data!;
    final list = await parseBody(
      await _api.fetchFacilities(l.id, partyId: userPartyId, branchCode: l.branch, currencyCode: cfCurrencyCode),
      CfFacility.listFromPayload,
    );
    if (list is! Success<List<CfFacility>>) return mapFailure(list);
    return ResponseHandler.success(CfFacilities(liability: l, roots: list.data ?? const []), code: 200);
  }

  /// `liabilities/{id}/facilities/{key}` → `facilityDTO`.
  Future<ResponseHandler<CfFacility>> fetchFacility(String key) async {
    final liability = await _liability();
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    final result = await parseBody(await _api.fetchFacility(liability.data!.id, key), CfFacility.detailFromPayload);
    if (result is Success<CfFacility?> && result.data != null) return ResponseHandler.success(result.data!, code: 200);
    if (result is Success<CfFacility?>) return ResponseHandler.error(200, null);
    return mapFailure(result);
  }

  /// The facility's collateral group with its linked collaterals, completed
  /// from the collaterals list (facility-details/hooks.js:316-383).
  Future<ResponseHandler<CfCollateralGroup?>> fetchCollateralGroup(String poolId, String userPartyId) async {
    final liability = await _liability();
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    final l = liability.data!;
    final (collaterals, group) = await (
      parseBody(
        await _api.fetchCollaterals(l.id, partyId: userPartyId, branchCode: l.branch, currencyCode: cfCurrencyCode),
        CfCollateral.listFromPayload,
      ),
      _api.fetchCollateralGroup(l.id, poolId),
    ).wait;
    final listed = collaterals is Success<List<CfCollateral>> ? collaterals.data ?? const <CfCollateral>[] : const <CfCollateral>[];
    return parseBody(group, (b) => CfCollateralGroup.fromPayload(b, listed));
  }

  /// The Overview's facility widgets: `liabilities?partyId=null` (the
  /// widgets pass `null`, sent as the text `null`, card §8.1), then the
  /// user party's facilities.
  Future<ResponseHandler<List<CfFacility>>> fetchOverviewFacilities(String userPartyId) async {
    final liability = await _liability(partyId: 'null');
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    final l = liability.data!;
    return parseBody(
      await _api.fetchFacilities(l.id, partyId: userPartyId, branchCode: l.branch, currencyCode: cfCurrencyCode),
      CfFacility.listFromPayload,
    );
  }

  /// The Overview's collateral widgets: as [fetchOverviewFacilities], for
  /// the collaterals.
  Future<ResponseHandler<List<CfCollateral>>> fetchOverviewCollaterals(String userPartyId) async {
    final liability = await _liability(partyId: 'null');
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    final l = liability.data!;
    return parseBody(
      await _api.fetchCollaterals(l.id, partyId: userPartyId, branchCode: l.branch, currencyCode: cfCurrencyCode),
      CfCollateral.listFromPayload,
    );
  }

  /// The collaterals list of the user's party (Choose Collateral).
  Future<ResponseHandler<List<CfCollateral>>> fetchCollaterals(String userPartyId) async {
    final liability = await _liability();
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    final l = liability.data!;
    return parseBody(
      await _api.fetchCollaterals(l.id, partyId: userPartyId, branchCode: l.branch, currencyCode: cfCurrencyCode),
      CfCollateral.listFromPayload,
    );
  }

  /// Collateral Summary (collateral-overview/hooks.js:106-170): the
  /// collaterals and the groups of the user's party together, then each
  /// group's own call for its linked collaterals. OBDX shows nothing until
  /// every group call has answered; one failing fails the page here too.
  Future<ResponseHandler<CfCollateralSummary>> fetchCollateralSummary(String userPartyId) async {
    final liability = await _liability();
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    final l = liability.data!;
    final (collaterals, groups) = await (
      _api.fetchCollaterals(l.id, partyId: userPartyId, branchCode: l.branch, currencyCode: cfCurrencyCode)
          .then((r) => parseBody(r, CfCollateral.listFromPayload)),
      _api.fetchCollateralGroups(l.id, partyId: userPartyId, branchCode: l.branch, currencyCode: cfCurrencyCode)
          .then((r) => parseBody(r, CfCollateralGroup.listFromPayload)),
    ).wait;
    if (collaterals is! Success<List<CfCollateral>>) return mapFailure(collaterals);
    if (groups is! Success<List<CfCollateralGroup>>) return mapFailure(groups);
    final listed = collaterals.data ?? const <CfCollateral>[];
    final details = await Future.wait([
      for (final g in groups.data ?? const <CfCollateralGroup>[])
        _api.fetchCollateralGroup(l.id, g.poolId).then((r) => parseBody(r, (b) => CfCollateralGroup.fromPayload(b, listed))),
    ]);
    final full = <CfCollateralGroup>[];
    for (final (i, g) in (groups.data ?? const <CfCollateralGroup>[]).indexed) {
      final detail = details[i];
      if (detail is! Success<CfCollateralGroup?>) return mapFailure(detail);
      full.add(g.withLinked(detail.data?.linked ?? const []));
    }
    return ResponseHandler.success(CfCollateralSummary(groups: full, collaterals: listed), code: 200);
  }

  /// Collateral Details: `liabilities` then `collaterals/{code}`.
  Future<ResponseHandler<CfCollateralDetail>> fetchCollateral(String code) async {
    final liability = await _liability();
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    final result = await parseBody(
      await _api.fetchCollateral(liability.data!.id, code),
      (b) => CfCollateralDetail.fromPayload(b, code),
    );
    if (result is Success<CfCollateralDetail?> && result.data != null) {
      return ResponseHandler.success(result.data!, code: 200);
    }
    if (result is Success<CfCollateralDetail?>) return ResponseHandler.error(200, null);
    return mapFailure(result);
  }

  /// Transaction Summary rows; dates as `yyyy-MM-dd` `[UNKNOWN]` format.
  Future<ResponseHandler<List<CfUtilizationRow>>> fetchUtilization(String key, {DateTime? from, DateTime? to}) async {
    final liability = await _liability();
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    return parseBody(
      await _api.fetchUtilization(liability.data!.id, key, fromDate: cfDate(from), toDate: cfDate(to)),
      CfUtilizationRow.listFromPayload,
    );
  }

  Future<ResponseHandler<List<int>>> downloadUtilization(String key, {DateTime? from, DateTime? to}) async {
    final liability = await _liability();
    if (liability is! Success<CfLiability>) return mapFailure(liability);
    return _api.downloadUtilization(liability.data!.id, key, fromDate: cfDate(from), toDate: cfDate(to));
  }
}

/// `2026-10-31`.
String? cfDate(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
