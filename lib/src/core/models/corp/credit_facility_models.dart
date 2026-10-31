import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Credit Facility Management (corporate): Facility Summary and Facility
/// Details. Shapes and rules from the OBDX source:
/// docs/obdx/features/credit-facility.md §2, §4, §5.

/// OBDX hard-codes this currency on every list call (card §2).
const cfCurrencyCode = 'INR';

/// `liabilities` → `liabilitydtos[]`. OBDX only ever uses the first one.
class CfLiability {
  const CfLiability({required this.id, this.branch, this.name, this.partyId});

  final String id;
  final String? branch;
  final String? name;
  final String? partyId;

  static CfLiability? firstFrom(Map<String, dynamic> body) {
    final list = body['liabilitydtos'];
    if (list is! List || list.isEmpty) return null;
    final m = ObdxApiUtils.asMap(list.first);
    final id = _str(m['id']);
    if (id == null) return null;
    return CfLiability(id: id, branch: _str(m['branch']), name: _str(m['name']), partyId: _str(m['partyId']));
  }
}

/// A facility (line), from `facilitydtos[]` or `facilityDTO`.
class CfFacility {
  const CfFacility({
    required this.lineCode,
    required this.lineSerialNumber,
    this.mainLineCode,
    this.category,
    this.categoryDesc,
    this.description,
    this.revolving = false,
    this.status,
    this.facilityType,
    this.currencyCode,
    this.limitAmount,
    this.effectiveAmount,
    this.utilizedAmount,
    this.availableAmount,
    this.blockAmount,
    this.collateralAmount,
    this.lineStartDate,
    this.expiryDate,
    this.partyId,
    this.children = const [],
    this.schedule = const [],
    this.covenants = const [],
    this.poolId,
    this.poolPercentage,
  });

  final String lineCode;
  final String lineSerialNumber;

  /// Empty for a main line, else the line it belongs to.
  final String? mainLineCode;
  final String? category;
  final String? categoryDesc;
  final String? description;
  final bool revolving;
  final String? status;
  final String? facilityType;
  final String? currencyCode;
  final MoneyAmount? limitAmount;

  /// Shown as "Sanctioned Amount".
  final MoneyAmount? effectiveAmount;
  final MoneyAmount? utilizedAmount;
  final MoneyAmount? availableAmount;
  final MoneyAmount? blockAmount;

  /// Shown as "Collateral Value" (in the available amount's currency).
  final MoneyAmount? collateralAmount;
  final DateTime? lineStartDate;

  /// Not in OBDX's sample response `[UNKNOWN]`; read when sent.
  final DateTime? expiryDate;
  final String? partyId;
  final List<CfFacility> children;
  final List<CfScheduleRow> schedule;
  final List<CfCovenant> covenants;

  /// `collateralPool[0].collateralGroupDTO.poolId` and its `poolPercentage`.
  final String? poolId;
  final double? poolPercentage;

  /// OBDX's key and the Facility Details path id: `lineCode_lineSerialNumber`.
  String get key => '${lineCode}_$lineSerialNumber';

  bool get isMainLine => (mainLineCode ?? '').isEmpty;

  /// "{n} % Utilized": utilized / sanctioned, two decimals (hooks.js).
  double get utilizedPercent {
    final total = effectiveAmount?.amount ?? 0;
    if (total == 0) return 0;
    return (((utilizedAmount?.amount ?? 0) / total) * 10000).round() / 100;
  }

  static List<CfFacility> listFromPayload(Map<String, dynamic> body) =>
      [for (final f in _maps(body['facilitydtos'])) if (CfFacility.fromJson(f) case final facility?) facility];

  /// Facility Details: `facilityDTO`.
  static CfFacility? detailFromPayload(Map<String, dynamic> body) =>
      CfFacility.fromJson(ObdxApiUtils.asMap(body['facilityDTO']));

  static CfFacility? fromJson(Map<String, dynamic> m) {
    final code = _str(m['lineCode']);
    if (code == null) return null;
    final pool = _maps(m['collateralPool']).firstOrNull;
    final group = pool == null ? const <String, dynamic>{} : ObdxApiUtils.asMap(pool['collateralGroupDTO']);
    return CfFacility(
      lineCode: code,
      lineSerialNumber: _str(m['lineSerialNumber']) ?? '',
      mainLineCode: _str(m['mainLineCode']),
      category: _str(m['category']),
      categoryDesc: _str(m['categoryDesc']),
      description: _str(m['description']),
      revolving: m['revolvingLine'] == true || '${m['revolvingLine']}'.toLowerCase() == 'true',
      status: _str(m['status']),
      facilityType: _str(m['facilityType']),
      currencyCode: _str(m['currencyCode']),
      limitAmount: _money(m['limitAmount']),
      effectiveAmount: _money(m['effectiveAmount']),
      utilizedAmount: _money(m['utilizedAmount']),
      availableAmount: _money(m['availableAmount']),
      blockAmount: _money(m['blockAmount']),
      collateralAmount: _money(m['collateralAmount']),
      lineStartDate: _date(m['lineStartDate']),
      expiryDate: _date(m['expiryDate']),
      partyId: _str(ObdxApiUtils.asMap(m['partyId'])['value']) ?? _str(m['partyId'] is Map ? null : m['partyId']),
      children: [for (final c in _maps(m['childFacilities'])) if (CfFacility.fromJson(c) case final child?) child],
      schedule: [
        for (final s in _maps(m['scheduleDetails']))
          CfScheduleRow(date: _date(s['limitDate']), amount: _money(s['limitAmount'])),
      ],
      covenants: [
        for (final c in _maps(m['covenantDTO']))
          CfCovenant(
            name: _str(c['covenantName']),
            revisionDate: _date(c['revisionDate']),
            description: _str(c['description']),
          ),
      ],
      poolId: _str(group['poolId']),
      poolPercentage: _num(pool?['poolPercentage']),
    );
  }

  /// Every facility and sub-facility, depth first (OBDX `convertTreeToArray`).
  static List<CfFacility> flatten(List<CfFacility> roots) => [
        for (final f in roots) ...[f, ...flatten(f.children)],
      ];

  /// The main line holding [key], for View Hierarchy, or null.
  static CfFacility? mainLineOf(List<CfFacility> roots, String key) {
    bool holds(CfFacility f) => f.key == key || f.children.any(holds);
    return roots.where(holds).firstOrNull;
  }
}

class CfScheduleRow {
  const CfScheduleRow({this.date, this.amount});

  final DateTime? date;
  final MoneyAmount? amount;
}

class CfCovenant {
  const CfCovenant({this.name, this.revisionDate, this.description});

  final String? name;
  final DateTime? revisionDate;
  final String? description;
}

/// Expiring In: OBDX's options (facility-summary-filter).
enum CfExpiry {
  days15(15, '15 days'),
  days30(30, '30 days'),
  days60(60, '60 days'),
  days90(90, '90 days'),
  days120(120, '120 days'),
  customize(null, 'Customize'),
  noExpiry(null, 'No Expiry');

  const CfExpiry(this.days, this.label);
  final int? days;
  final String label;
}

/// Facility Summary Filter: all client-side (card §4.4).
class CfFilter {
  const CfFilter({
    this.lineCode,
    this.category,
    this.revolving,
    this.expiry,
    this.customDays,
    this.currency,
    this.minAvailable,
    this.maxAvailable,
  });

  static const none = CfFilter();

  final String? lineCode;
  final String? category;
  final bool? revolving;
  final CfExpiry? expiry;
  final int? customDays;
  final String? currency;
  final double? minAvailable;
  final double? maxAvailable;

  int get count => [lineCode, category, revolving, expiry, currency, minAvailable ?? maxAvailable]
      .where((v) => v != null)
      .length;

  /// OBDX's rules: line code and category exact (ignoring case); expiry
  /// |expiryDate − today| ≤ N days, or no expiry date; amount range on
  /// the available amount. [partyId] (the selected party) also filters.
  List<CfFacility> apply(List<CfFacility> rows, DateTime today, {String? partyId}) {
    final day = DateTime(today.year, today.month, today.day);
    bool keep(CfFacility f) {
      if (partyId != null && partyId.isNotEmpty && f.partyId != null && f.partyId != partyId) return false;
      if (lineCode != null && f.lineCode.toLowerCase() != lineCode!.toLowerCase()) return false;
      if (category != null && (f.category ?? '').toLowerCase() != category!.toLowerCase()) return false;
      if (revolving != null && f.revolving != revolving) return false;
      if (currency != null && f.currencyCode != currency) return false;
      final available = f.availableAmount?.amount;
      if (minAvailable != null && (available == null || available < minAvailable!)) return false;
      if (maxAvailable != null && (available == null || available > maxAvailable!)) return false;
      if (expiry == CfExpiry.noExpiry) return f.expiryDate == null;
      final days = expiry == CfExpiry.customize ? customDays : expiry?.days;
      if (days != null) {
        final e = f.expiryDate;
        if (e == null) return false;
        if (DateTime(e.year, e.month, e.day).difference(day).inDays.abs() > days) return false;
      }
      return true;
    }

    return rows.where(keep).toList();
  }
}

/// Transaction Summary: `utilization` → `historyDetails[]`.
class CfUtilizationRow {
  const CfUtilizationRow({this.date, this.reference, this.type, this.amount, this.available});

  final DateTime? date;
  final String? reference;
  final String? type;
  final MoneyAmount? amount;
  final MoneyAmount? available;

  static List<CfUtilizationRow> listFromPayload(Map<String, dynamic> body) => [
        for (final r in _maps(body['historyDetails']))
          CfUtilizationRow(
            date: _date(r['utilizationDate']),
            reference: _str(r['userRefNo']),
            type: _str(r['transactionType']),
            amount: _money(r['amount']),
            available: _money(r['availableAmount']),
          ),
      ];

  bool matches(String query) {
    final q = query.toLowerCase();
    return [type, reference, amount?.amount.toString(), available?.amount.toString()]
        .any((v) => v != null && v.toLowerCase().contains(q));
  }
}

/// A collateral in `collaterals` → `collateraldtos[]` (only the fields the
/// Collateral Groups tab reads).
class CfCollateral {
  const CfCollateral({required this.code, this.value, this.limitContribution, this.endDate, this.lendableMargin});

  final String code;
  final MoneyAmount? value;
  final MoneyAmount? limitContribution;
  final DateTime? endDate;
  final num? lendableMargin;

  static List<CfCollateral> listFromPayload(Map<String, dynamic> body) => [
        for (final c in _maps(body['collateraldtos']))
          if (_str(c['collateralCode']) case final code?)
            CfCollateral(
              code: code,
              value: _money(c['collateralValue']),
              limitContribution: _money(c['limitContribution']),
              endDate: _date(c['endDate']),
              lendableMargin: _num(c['lendableMargin']),
            ),
      ];
}

/// `collateralgroups/{poolId}` → `collateralGroupDTO`, with its linked
/// collaterals completed from the collaterals list, as Facility Details
/// does (hooks.js:316-341).
class CfCollateralGroup {
  const CfCollateralGroup({
    required this.poolId,
    this.groupAmount,
    this.utilizedAmount,
    this.blockAmount,
    this.availableAmount,
    this.linked = const [],
  });

  final String poolId;
  final MoneyAmount? groupAmount;
  final MoneyAmount? utilizedAmount;
  final MoneyAmount? blockAmount;
  final MoneyAmount? availableAmount;
  final List<CfLinkedCollateral> linked;

  /// "Utilized Amount": utilized + block (collateral-groups.html).
  double get shownUtilized => (utilizedAmount?.amount ?? 0) + (blockAmount?.amount ?? 0);

  /// "Block Amount": group − (utilized + block + available), as OBDX shows it.
  double get shownBlock =>
      (groupAmount?.amount ?? 0) -
      ((utilizedAmount?.amount ?? 0) + (blockAmount?.amount ?? 0) + (availableAmount?.amount ?? 0));

  /// "Contribution to Facility": round(group × pool % / 100).
  double contribution(double? poolPercentage) => ((groupAmount?.amount ?? 0) * ((poolPercentage ?? 0) / 100)).roundToDouble();

  static CfCollateralGroup? fromPayload(Map<String, dynamic> body, List<CfCollateral> collaterals) {
    final g = ObdxApiUtils.asMap(body['collateralGroupDTO']);
    final pool = _str(g['poolId']);
    if (pool == null) return null;
    return CfCollateralGroup(
      poolId: pool,
      groupAmount: _money(g['groupAmount']),
      utilizedAmount: _money(g['groupUtilizedAmount']),
      blockAmount: _money(g['groupBlockAmount']),
      availableAmount: _money(g['availableAmount']),
      linked: [
        for (final s in _maps(g['sharedCollateral']))
          if (_str(ObdxApiUtils.asMap(s['collateralDetails'])['collateralCode']) case final code?)
            CfLinkedCollateral.from(s, code, collaterals.where((c) => c.code == code).firstOrNull),
      ],
    );
  }
}

class CfLinkedCollateral {
  const CfLinkedCollateral({
    required this.code,
    this.description,
    this.value,
    this.limitContribution,
    this.endDate,
    this.lendableMargin,
    this.utilization,
    this.contributionPercent,
  });

  final String code;
  final String? description;

  /// From the collaterals list: Collateral Value, Collateral Amount (After
  /// Haircut), End Date, Margin.
  final MoneyAmount? value;
  final MoneyAmount? limitContribution;
  final DateTime? endDate;
  final num? lendableMargin;

  /// "Contribution to Group": `utilizationAmount` and
  /// `allocatedGroupContributionInPercentage`.
  final MoneyAmount? utilization;
  final num? contributionPercent;

  factory CfLinkedCollateral.from(Map<String, dynamic> shared, String code, CfCollateral? listed) {
    final d = ObdxApiUtils.asMap(shared['collateralDetails']);
    return CfLinkedCollateral(
      code: code,
      description: _str(d['collateralDesc']),
      value: listed?.value,
      limitContribution: listed?.limitContribution,
      endDate: listed?.endDate,
      lendableMargin: listed?.lendableMargin,
      utilization: _money(d['utilizationAmount']),
      contributionPercent: _num(shared['allocatedGroupContributionInPercentage']),
    );
  }
}

/// A party for Selected Party: the user's own, then related parties
/// (`me/party`, `me/party/relations`), shown `name|id`.
class CfParty {
  const CfParty({required this.id, required this.display, this.name});

  final String id;
  final String display;
  final String? name;

  String get label => name == null ? display : '$name|$display';

  static CfParty? own(Map<String, dynamic> body) {
    final p = ObdxApiUtils.asMap(body['party']);
    final id = ObdxApiUtils.asMap(p['id']);
    final value = _str(id['value']);
    if (value == null) return null;
    return CfParty(
      id: value,
      display: _str(id['displayValue']) ?? value,
      name: _str(ObdxApiUtils.asMap(p['personalDetails'])['fullName']),
    );
  }

  static List<CfParty> related(Map<String, dynamic> body) => [
        for (final r in _maps(body['partyToPartyRelationship']))
          if (_str(ObdxApiUtils.asMap(r['relatedParty'])['value']) case final value?)
            CfParty(
              id: value,
              display: _str(ObdxApiUtils.asMap(r['relatedParty'])['displayValue']) ?? value,
              name: _str(r['relatedPartyName']) ?? _str(ObdxApiUtils.asMap(r['relatedParty'])['relatedPartyName']),
            ),
      ];
}

/// What Facility Summary loads beside the facilities.
class CfLookups {
  const CfLookups({this.parties = const [], this.currencies = const [], this.groupCorporate});

  static const empty = CfLookups();

  final List<CfParty> parties;

  /// `currency` → `currencyList[].code`.
  final List<String> currencies;

  /// "Group Corporate Id" row: `id | name`, when the user has one.
  final String? groupCorporate;

  static List<String> currenciesFrom(Map<String, dynamic> body) =>
      [for (final c in _maps(body['currencyList'])) if (_str(c['code']) case final code?) code];
}

List<Map<String, dynamic>> _maps(dynamic raw) =>
    raw is List ? [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)] : const [];

MoneyAmount? _money(dynamic raw) => raw == null ? null : MoneyAmount.fromJson(raw);

DateTime? _date(dynamic raw) => raw == null ? null : DateTime.tryParse('$raw');

double? _num(dynamic raw) => raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');

String? _str(dynamic v) {
  if (v == null || v is Map || v is List) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}
