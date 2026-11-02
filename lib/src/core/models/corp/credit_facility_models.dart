import 'package:demo_bank/src/core/models/common/money_amount.dart';
import 'package:demo_bank/src/infra/network/obdx_api_utils.dart';

/// Credit Facility Management (corporate): the Overview widgets, Facility
/// Summary / Details and Collateral Summary / Details. Shapes and rules
/// from the OBDX source: docs/obdx/features/credit-facility.md §2-§7.

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
    this.effectiveBase,
    this.utilizedBase,
    this.availableBase,
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

  /// `effectiveAmountInBaseCurr` / `utilizedAmountInBaseCurr` /
  /// `availableAmountInBaseCurr`: the Overview's Local Currency figures.
  final MoneyAmount? effectiveBase;
  final MoneyAmount? utilizedBase;
  final MoneyAmount? availableBase;
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
      effectiveBase: _money(m['effectiveAmountInBaseCurr']),
      utilizedBase: _money(m['utilizedAmountInBaseCurr']),
      availableBase: _money(m['availableAmountInBaseCurr']),
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
      covenants: CfCovenant.listFrom(m['covenantDTO']),
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

  /// `covenantDTO[]` of a facility or a collateral.
  static List<CfCovenant> listFrom(dynamic raw) => [
        for (final c in _maps(raw))
          CfCovenant(
            name: _str(c['covenantName']),
            revisionDate: _date(c['revisionDate']),
            description: _str(c['description']),
          ),
      ];
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

/// A collateral in `collaterals` → `collateraldtos[]` (sample
/// `design-dashboard/credit-facility/collateral.json`).
class CfCollateral {
  const CfCollateral({
    required this.code,
    this.category,
    this.description,
    this.value,
    this.limitContribution,
    this.availableAmount,
    this.utilization,
    this.utilizationBase,
    this.availableBase,
    this.equivalentLimitContribution,
    this.equivalentBlock,
    this.startDate,
    this.endDate,
    this.lendableMargin,
  });

  final String code;

  /// `collateralCategory`: the filter's Collateral Type.
  final String? category;
  final String? description;
  final MoneyAmount? value;
  final MoneyAmount? limitContribution;
  final MoneyAmount? availableAmount;

  /// `utilizationAmount` (Collateral Currency) and the `…InBaseCurr` /
  /// `equivalent…` figures (Local Currency) the Overview widgets read.
  /// `equivalentBlockAmount` is not in OBDX's sample `[UNKNOWN]`; 0 when
  /// missing, as OBDX does.
  final MoneyAmount? utilization;
  final MoneyAmount? utilizationBase;
  final MoneyAmount? availableBase;
  final MoneyAmount? equivalentLimitContribution;
  final MoneyAmount? equivalentBlock;
  final DateTime? startDate;
  final DateTime? endDate;
  final num? lendableMargin;

  static List<CfCollateral> listFromPayload(Map<String, dynamic> body) => [
        for (final c in _maps(body['collateraldtos']))
          if (_str(c['collateralCode']) case final code?)
            CfCollateral(
              code: code,
              category: _str(c['collateralCategory']),
              description: _str(c['collateralDesc']),
              value: _money(c['collateralValue']),
              limitContribution: _money(c['limitContribution']),
              availableAmount: _money(c['availableAmount']),
              utilization: _money(c['utilizationAmount']),
              utilizationBase: _money(c['utilizationAmountInBaseCurr']),
              availableBase: _money(c['availableAmountInBaseCurr']),
              equivalentLimitContribution: _money(c['equivalentLimitContribution']),
              equivalentBlock: _money(c['equivalentBlockAmount']),
              startDate: _date(c['startDate']),
              endDate: _date(c['endDate']),
              lendableMargin: _num(c['lendableMargin']),
            ),
      ];

  /// Collateral Allocation's "{n} % Utilized": round2((utilized + block,
  /// in local currency) × 100 / equivalent limit contribution). OBDX
  /// divides by zero when the contribution is 0 (card §8.18); 0 here.
  double get allocationUtilizedPercent {
    final limit = equivalentLimitContribution?.amount ?? 0;
    if (limit == 0) return 0;
    final used = (utilizationBase?.amount ?? 0) + (equivalentBlock?.amount ?? 0);
    return (used * 100 / limit * 100).round() / 100;
  }
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
    this.externalReferenceId,
    this.linked = const [],
  });

  final String poolId;

  /// The filter's Group ID is matched against this, not [poolId].
  final String? externalReferenceId;
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

  /// The "{n}% Utilized" bar: round2((utilized + block) × 100 / group);
  /// 0 for a zero group (collateral-overview/hooks.js progressValue).
  double get utilizedPercent {
    final total = groupAmount?.amount ?? 0;
    if (total == 0) return 0;
    return (shownUtilized * 100 / total * 100).round() / 100;
  }

  /// "Contribution to Facility": round(group × pool % / 100).
  double contribution(double? poolPercentage) => ((groupAmount?.amount ?? 0) * ((poolPercentage ?? 0) / 100)).roundToDouble();

  /// `collateralgroups` → `collateralgroupdtos[]`, without linked
  /// collaterals (those come from each group's own call).
  static List<CfCollateralGroup> listFromPayload(Map<String, dynamic> body) => [
        for (final g in _maps(body['collateralgroupdtos']))
          if (_fromDto(g, const [], const []) case final group?) group,
      ];

  static CfCollateralGroup? fromPayload(Map<String, dynamic> body, List<CfCollateral> collaterals) {
    final g = ObdxApiUtils.asMap(body['collateralGroupDTO']);
    return _fromDto(g, _maps(g['sharedCollateral']), collaterals);
  }

  /// This group with the linked collaterals of its own call.
  CfCollateralGroup withLinked(List<CfLinkedCollateral> linked) => CfCollateralGroup(
        poolId: poolId,
        groupAmount: groupAmount,
        utilizedAmount: utilizedAmount,
        blockAmount: blockAmount,
        availableAmount: availableAmount,
        externalReferenceId: externalReferenceId,
        linked: linked,
      );

  static CfCollateralGroup? _fromDto(
      Map<String, dynamic> g, List<Map<String, dynamic>> shared, List<CfCollateral> collaterals) {
    final pool = _str(g['poolId']);
    if (pool == null) return null;
    return CfCollateralGroup(
      poolId: pool,
      groupAmount: _money(g['groupAmount']),
      utilizedAmount: _money(g['groupUtilizedAmount']),
      blockAmount: _money(g['groupBlockAmount']),
      availableAmount: _money(g['availableAmount']),
      externalReferenceId: _str(g['externalReferenceId']),
      linked: [
        for (final s in shared)
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
    this.type,
    this.value,
    this.limitContribution,
    this.endDate,
    this.lendableMargin,
    this.utilization,
    this.contributionPercent,
  });

  final String code;
  final String? description;

  /// `collateralDetails.collateralType`, else the listed category: the
  /// filter's Collateral Type.
  final String? type;

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
      type: _str(d['collateralType']) ?? listed?.category,
      value: listed?.value,
      limitContribution: listed?.limitContribution,
      endDate: listed?.endDate,
      lendableMargin: listed?.lendableMargin,
      utilization: _money(d['utilizationAmount']),
      contributionPercent: _num(shared['allocatedGroupContributionInPercentage']),
    );
  }
}

/// The Overview's widgets (`components/widgets/credit-facility/`), by
/// OBDX `componentName`, in `moduleComponents.json` order — the order used
/// when the server layout cannot be read.
enum CfOverviewWidget {
  collateralAllocation('collateral-allocation'),
  collateralSynopsis('collateral-synopsis'),
  facilityAllocation('facility-allocation'),
  facilitySynopsis('facility-synopsis');

  const CfOverviewWidget(this.componentName);

  final String componentName;

  /// The module dashboard's `value` (`dashboards/modules?class=MODULE&value=`).
  static const module = 'credit-facility';

  static CfOverviewWidget? byName(String name) {
    for (final w in values) {
      if (w.componentName == name) return w;
    }
    return null;
  }

  /// The known widgets among the server layout's component names, in its
  /// order; every widget in [values] order when none is known.
  static List<CfOverviewWidget> fromLayout(Iterable<String> names) {
    final known = [for (final n in names) if (byName(n) case final w?) w];
    return known.isEmpty ? values : {...known}.toList();
  }
}

/// A synopsis widget's figures (Facility: Sanctioned / Utilized /
/// Available; Collateral: Collateral / Utilized / Available), all in local
/// currency, with the "Utilized Status" split.
class CfSynopsis {
  const CfSynopsis({required this.total, required this.utilized, required this.available, this.currency});

  final double total;
  final double utilized;
  final double available;

  /// The last row's `availableAmountInBaseCurr.currency`, as OBDX takes it.
  final String? currency;

  /// round(utilized / total × 100); 0 for a zero total (OBDX shows NaN).
  int get utilizedPercent => total == 0 ? 0 : (utilized / total * 100).round();

  int get availablePercent => 100 - utilizedPercent;

  /// facility-synopsis/hooks.js:51-66: sums over `facilitydtos` (the main
  /// lines).
  static CfSynopsis? facilities(List<CfFacility> roots) {
    if (roots.isEmpty) return null;
    return CfSynopsis(
      total: _sum(roots.map((f) => f.effectiveBase)),
      utilized: _sum(roots.map((f) => f.utilizedBase)),
      available: _sum(roots.map((f) => f.availableBase)),
      currency: roots.last.availableBase?.currency,
    );
  }

  /// collateral-synopsis/hooks.js:53-67: Collateral = Σ equivalent limit
  /// contribution; Utilized = Σ (utilized + block); Available = the
  /// difference.
  static CfSynopsis? collaterals(List<CfCollateral> rows) {
    if (rows.isEmpty) return null;
    final total = _sum(rows.map((c) => c.equivalentLimitContribution));
    final used = _sum(rows.map((c) => c.utilizationBase)) + _sum(rows.map((c) => c.equivalentBlock));
    return CfSynopsis(total: total, utilized: used, available: total - used, currency: rows.last.availableBase?.currency);
  }
}

/// One category of an allocation widget: its rows, its total in local
/// currency and its share of the grand total (the tab's "%").
class CfAllocationSlice<T> {
  const CfAllocationSlice({required this.category, required this.total, required this.share, required this.rows});

  final String category;
  final double total;
  final double share;
  final List<T> rows;
}

/// An allocation widget's donut and tabs: rows grouped by category in
/// first-seen order.
class CfAllocation<T> {
  const CfAllocation({required this.slices, required this.total, this.currency});

  final List<CfAllocationSlice<T>> slices;

  /// The donut's centre figure, in local currency.
  final double total;
  final String? currency;

  /// facility-allocation/hooks.js:122-186: by `category`, valued at
  /// `effectiveAmountInBaseCurr`; share round2.
  static CfAllocation<CfFacility>? facilities(List<CfFacility> roots) =>
      _group(roots, (f) => f.category ?? '', (f) => f.effectiveBase, roots.lastOrNull?.effectiveBase?.currency);

  /// collateral-allocation/hooks.js:112-180: by `collateralCategory`,
  /// valued at `equivalentLimitContribution`; share `toFixed(2)`.
  static CfAllocation<CfCollateral>? collaterals(List<CfCollateral> rows) => _group(
      rows, (c) => c.category ?? '', (c) => c.equivalentLimitContribution, rows.lastOrNull?.utilizationBase?.currency);

  static CfAllocation<T>? _group<T>(
      List<T> rows, String Function(T) categoryOf, MoneyAmount? Function(T) valueOf, String? currency) {
    if (rows.isEmpty) return null;
    final groups = <String, List<T>>{};
    for (final r in rows) {
      groups.putIfAbsent(categoryOf(r), () => []).add(r);
    }
    final total = _sum(rows.map(valueOf));
    return CfAllocation(
      total: total,
      currency: currency,
      slices: [
        for (final MapEntry(:key, :value) in groups.entries)
          CfAllocationSlice(
            category: key,
            total: _sum(value.map(valueOf)),
            share: total == 0 ? 0 : (_sum(value.map(valueOf)) / total * 100 * 100).round() / 100,
            rows: value,
          ),
      ],
    );
  }
}

double _sum(Iterable<MoneyAmount?> amounts) => amounts.fold(0, (sum, m) => sum + (m?.amount ?? 0));

/// One row of Collateral Summary: a collateral group (OBDX type `P`) or a
/// collateral in no group (type `C`).
sealed class CfCollateralEntry {
  const CfCollateralEntry();

  /// The page's search ("Description") over `description`, `poolId`,
  /// `collateralCode` and `collateralDesc` (collateral-overview/hooks.js:81).
  bool matches(String query);
}

final class CfGroupEntry extends CfCollateralEntry {
  const CfGroupEntry(this.group);

  final CfCollateralGroup group;

  @override
  bool matches(String query) => _has(group.poolId, query);
}

final class CfLooseEntry extends CfCollateralEntry {
  const CfLooseEntry(this.collateral);

  final CfCollateral collateral;

  @override
  bool matches(String query) => _has(collateral.code, query) || _has(collateral.description, query);
}

bool _has(String? value, String query) => value != null && value.toLowerCase().contains(query.trim().toLowerCase());

/// Collateral Summary's data: the groups (each with its linked
/// collaterals) and every collateral of the user's party.
class CfCollateralSummary {
  const CfCollateralSummary({this.groups = const [], this.collaterals = const []});

  final List<CfCollateralGroup> groups;
  final List<CfCollateral> collaterals;

  /// OBDX's order: the collaterals in no group, then the groups
  /// (collateral-overview/hooks.js:117-161, `comparison`).
  List<CfCollateralEntry> get entries {
    final linked = {for (final g in groups) for (final c in g.linked) c.code};
    return [
      for (final c in collaterals) if (!linked.contains(c.code)) CfLooseEntry(c),
      for (final g in groups) CfGroupEntry(g),
    ];
  }

  /// The filter's Collateral Type options: distinct `collateralCategory`.
  List<String> get types => {for (final c in collaterals) if (c.category != null) c.category!}.toList();
}

/// Collateral Summary filter's Apply Filter choice.
enum CfCollateralFilterMode {
  byGroup('By Collateral Group'),
  byNonGroup('By Non Collateral Group'),
  byCollateral('By Collateral');

  const CfCollateralFilterMode(this.label);

  final String label;
}

/// Collateral Summary filter (collateral-overview-filter), client-side.
/// [amountMin]/[amountMax] is Group Amount Range in [byGroup] /
/// [byNonGroup] (on `collateralValue` there) and Collateral Amount Range in
/// [byCollateral]. Each range is inclusive with either end optional.
///
/// Fixed against OBDX (card §8.15, §10): Collateral ID is applied in By Non
/// Collateral Group; Available Amount Range is a plain min/max (OBDX mixes
/// in the group maximum); a group's available amount is its own
/// `availableAmount` (OBDX reads its first linked collateral's value);
/// Collateral Amount Range with one end set is a one-sided range (OBDX ORs
/// the two ends, so it matches everything).
class CfCollateralFilter {
  const CfCollateralFilter({
    this.mode,
    this.groupId,
    this.collateralId,
    this.type,
    this.amountMin,
    this.amountMax,
    this.availableMin,
    this.availableMax,
  });

  static const none = CfCollateralFilter();

  final CfCollateralFilterMode? mode;
  final String? groupId;
  final String? collateralId;
  final String? type;
  final double? amountMin;
  final double? amountMax;
  final double? availableMin;
  final double? availableMax;

  bool get isActive => mode != null;

  List<CfCollateralEntry> apply(List<CfCollateralEntry> rows) {
    final m = mode;
    if (m == null) return rows;
    return rows.where((r) => switch ((m, r)) {
          (CfCollateralFilterMode.byGroup, CfGroupEntry(:final group)) =>
            (groupId == null || group.externalReferenceId != null && _has(group.externalReferenceId, groupId!)) &&
                _inRange(group.groupAmount?.amount, amountMin, amountMax) &&
                _inRange(group.availableAmount?.amount, availableMin, availableMax),
          (CfCollateralFilterMode.byGroup, _) => false,
          (CfCollateralFilterMode.byNonGroup, CfLooseEntry(:final collateral)) =>
            _code(collateral.code) &&
                _inRange(collateral.value?.amount, amountMin, amountMax) &&
                _inRange(collateral.availableAmount?.amount, availableMin, availableMax),
          (CfCollateralFilterMode.byNonGroup, _) => false,
          (CfCollateralFilterMode.byCollateral, CfGroupEntry(:final group)) =>
            (type == null || group.linked.any((c) => c.type == type)) &&
                (collateralId == null || group.linked.any((c) => _code(c.code))) &&
                _inRange(group.groupAmount?.amount, amountMin, amountMax) &&
                _inRange(group.availableAmount?.amount, availableMin, availableMax),
          (CfCollateralFilterMode.byCollateral, CfLooseEntry(:final collateral)) =>
            (type == null || collateral.category == type) &&
                _code(collateral.code) &&
                _inRange(collateral.value?.amount, amountMin, amountMax) &&
                _inRange(collateral.availableAmount?.amount, availableMin, availableMax),
        }).toList();
  }

  bool _code(String code) => collateralId == null || _has(code, collateralId!);

  static bool _inRange(double? v, double? min, double? max) {
    if (min == null && max == null) return true;
    if (v == null) return false;
    return (min == null || v >= min) && (max == null || v <= max);
  }
}

/// How a per-type column is shown: as text, as money (in its own currency,
/// else the collateral's `availableAmount` currency) or as a date.
enum CfColumnKind { text, money, date }

typedef CfColumn = ({String label, String field, CfColumnKind kind});

const _t = CfColumnKind.text, _m = CfColumnKind.money, _d = CfColumnKind.date;

/// Collateral Details' More Information panel by `collateralType`
/// (collateral-details/hooks.js:102-134): each component's `tablecolumns`
/// with its nls label, field and formatter.
const Map<String, List<CfColumn>> cfCollateralColumns = {
  'PROPERTY': [
    (label: 'Property Type', field: 'propertyType', kind: _t),
    (label: 'Address', field: 'address', kind: _t),
    (label: 'Basis Of Property Value', field: 'basisOfPropertyValue', kind: _t),
    (label: 'Government Value', field: 'governmentValue', kind: _m),
    (label: 'Market Value', field: 'marketValue', kind: _m),
    (label: 'Property Index Value', field: 'propertyIndexValue', kind: _m),
    (label: 'Purchase Date', field: 'purchaseDate', kind: _d),
  ],
  'VEHICLE': [
    (label: 'Vehicle Type', field: 'vehicleType', kind: _t),
    (label: 'Model', field: 'model', kind: _t),
    (label: 'Owner', field: 'owner', kind: _t),
    (label: 'Valuation Amount', field: 'valuationAmount', kind: _m),
    (label: 'Chassis Number', field: 'chassisNumber', kind: _t),
    (label: 'Engine Number', field: 'engineNumber', kind: _t),
    (label: 'Registration Authority', field: 'registrationAuthority', kind: _t),
    (label: 'Registration Number', field: 'registrationNumber', kind: _t),
  ],
  'LIFEINSURANCE': [
    (label: 'Policy Number', field: 'policyNumber', kind: _t),
    (label: 'Policy Start Date', field: 'policyStartDate', kind: _d),
    (label: 'Premium Amount', field: 'premiumAmount', kind: _m),
    (label: 'Assignment Date', field: 'assignmentDate', kind: _d),
    (label: 'Insurance Amount', field: 'insuranceAmount', kind: _m),
    (label: 'Insurer Details', field: 'insurerDetails', kind: _t),
  ],
  'ACCOUNTS CONTRACTS': [
    (label: 'Reference Number', field: 'referenceNumber', kind: _t),
    (label: 'Account Type', field: 'accountType', kind: _t),
    (label: 'Value Date', field: 'valueDate', kind: _d),
    (label: 'Account Balance', field: 'balance', kind: _m),
    (label: 'Lien Amount', field: 'lienAmount', kind: _m),
    (label: 'Branch', field: 'branch', kind: _t),
  ],
  'BOND': [
    (label: 'Security Code', field: 'securityCode', kind: _t),
    (label: 'Holder', field: 'holderName', kind: _t),
    (label: 'Bond Amount', field: 'amount', kind: _m),
    (label: 'Bond Tenure', field: 'bondDuration', kind: _t),
    (label: 'Folio Number', field: 'folioNumber', kind: _t),
    (label: 'Issued Date', field: 'issueDate', kind: _d),
    (label: 'Issuer', field: 'issuer', kind: _t),
    (label: 'Maturity Date', field: 'maturityDate', kind: _d),
    (label: 'Price Code', field: 'priceId', kind: _t),
    (label: 'Quantity', field: 'quantity', kind: _t),
    (label: 'Unit Value', field: 'pricePerUnit', kind: _m),
    (label: 'Base Currency Value', field: 'amountInCollateralCurrency', kind: _m),
  ],
  'COMMERCIAL PAPER': [
    (label: 'Issuer Name', field: 'issuerName', kind: _t),
    (label: 'Security Code', field: 'securityCode', kind: _t),
    (label: 'Interest Rate', field: 'interestRate', kind: _t),
    (label: 'Issued Date', field: 'issueDate', kind: _d),
    (label: 'Market Value', field: 'marketValue', kind: _m),
    (label: 'Maturity Amount', field: 'maturityAmount', kind: _m),
    (label: 'Maturity Date', field: 'maturityDate', kind: _d),
    (label: 'Maturity Period', field: 'maturityPeriod', kind: _t),
    (label: 'Price Code', field: 'priceId', kind: _t),
    (label: 'Unit Value', field: 'pricePerUnit', kind: _m),
    (label: 'Reference Number', field: 'referenceNumber', kind: _t),
    (label: 'Base Currency Value', field: 'amountInCollateralCurrency', kind: _m),
  ],
  'COMMODITY': [
    (label: 'Commodity Details', field: 'collateralDetails', kind: _t),
    (label: 'Description', field: 'description', kind: _t),
    (label: 'Reference Number', field: 'referenceNumber', kind: _t),
    (label: 'Commodity Type', field: 'type', kind: _t),
    (label: 'Quantity', field: 'quantity', kind: _t),
    (label: 'Unit Value', field: 'pricePerUnit', kind: _m),
    (label: 'Market Value', field: 'marketValue', kind: _m),
  ],
  'CORPORATE DEPOSIT': [
    (label: 'Reference Number', field: 'referenceNumber', kind: _t),
    (label: 'Category', field: 'category', kind: _t),
    (label: 'Deposit Amount', field: 'depositAmount', kind: _m),
    (label: 'Deposit Date', field: 'depositDate', kind: _d),
    (label: 'Interest Payment Type', field: 'interestPaymentType', kind: _t),
    (label: 'Issuer Name', field: 'issuerName', kind: _t),
    (label: 'Maturity Date', field: 'maturityDate', kind: _d),
    (label: 'Maturity Amount', field: 'maturityAmount', kind: _m),
  ],
  'PERISHABLE': [
    (label: 'Name Of Perishable', field: 'name', kind: _t),
    (label: 'Type', field: 'type', kind: _t),
    (label: 'Quantity Unit', field: 'quantityUnit', kind: _t),
    (label: 'Total Produced', field: 'totalProduced', kind: _t),
    (label: 'Market Value', field: 'marketValue', kind: _m),
    (label: 'Date Of Harvested', field: 'dateOfHarvested', kind: _d),
    (label: 'End Date', field: 'endDate', kind: _d),
    (label: 'Base Currency Value', field: 'amountInCollateralCurrency', kind: _m),
  ],
  'FUND': [
    (label: 'Name Of Fund', field: 'name', kind: _t),
    (label: 'Security Code', field: 'securityCode', kind: _t),
    (label: 'Holder', field: 'holderName', kind: _t),
    (label: 'Total Amount', field: 'totalAmount', kind: _m),
    (label: 'Folio Number', field: 'folioNumber', kind: _t),
    (label: 'Issuer', field: 'issuer', kind: _t),
    (label: 'Price Code', field: 'priceId', kind: _t),
    (label: 'Quantity', field: 'quantity', kind: _t),
    (label: 'Unit Value', field: 'unitValue', kind: _m),
  ],
  'PRECIOUSMETALS': [
    (label: 'Precious Metal Form', field: 'preciousMetalForm', kind: _t),
    (label: 'Precious Metal Type', field: 'preciousMetalType', kind: _t),
    (label: 'Unit Rate', field: 'unitRate', kind: _m),
    (label: 'Valuation Amount', field: 'valuationAmount', kind: _m),
    (label: 'Weight In Grams', field: 'weightInGms', kind: _t),
  ],
  'GUARANTEE': [
    (label: 'Guarantor Name', field: 'guarantorName', kind: _t),
    (label: 'Guarantee Type', field: 'guaranteeType', kind: _t),
    (label: 'Guarantee Amount', field: 'guaranteeAmount', kind: _m),
    (label: 'Total Guarantee Amount', field: 'totalGuaranteeAmount', kind: _m),
  ],
  'INVENTORY': [
    (label: 'Cost Of Finished Goods', field: 'costOfFinishedGoods', kind: _m),
    (label: 'Cost Of Obsolete Inventory', field: 'costOfObsoluteInventory', kind: _m),
    (label: 'Cost Of Raw Materials', field: 'costOfRawMaterials', kind: _m),
    (label: 'Cost Of Work In Progress', field: 'costOfWorkInProgress', kind: _m),
    (label: 'Lien Amount', field: 'lienAmount', kind: _m),
    (label: 'Total Cost', field: 'totalCost', kind: _m),
    (label: 'Total Inventory Cost', field: 'total', kind: _m),
    // A link that opens Product Details over `products` (cfInventoryProductColumns).
    (label: 'Inventory Product Details', field: 'products', kind: _t),
  ],
  'BILL OF EXCHANGE': [
    (label: 'Payee', field: 'payee', kind: _t),
    (label: 'Place Of Issue', field: 'placeOfIssue', kind: _t),
    (label: 'Status', field: 'status', kind: _t),
    (label: 'Type', field: 'type', kind: _t),
    (label: 'Issuing Bank Details', field: 'issuingBankDetails', kind: _t),
    (label: 'Bill Date', field: 'billDate', kind: _d),
    (label: 'Presentment Date', field: 'dateOfPresentment', kind: _d),
    (label: 'Due Date', field: 'dueDate', kind: _d),
    (label: 'Drawer', field: 'drawer', kind: _t),
  ],
  'PLANTMACHINERY': [
    (label: 'Machine Detail', field: 'machineDetail', kind: _t),
    (label: 'Machine Value Basis', field: 'machineValueBasis', kind: _t),
    (label: 'Machinery Location', field: 'machineryLocation', kind: _t),
    (label: 'Manufacturer', field: 'manufacturer', kind: _t),
    (label: 'Assessed Value', field: 'assessedvalue', kind: _m),
    (label: 'Invoice Value', field: 'invoiceValue', kind: _m),
    (label: 'Replacement Value', field: 'replacementValue', kind: _m),
    (label: 'Written Down Value', field: 'writtenDownValue', kind: _m),
  ],
  'STOCK': [
    (label: 'Security Code', field: 'securityCode', kind: _t),
    (label: 'Holder', field: 'holderName', kind: _t),
    (label: 'Stock Amount', field: 'amount', kind: _m),
    (label: 'Folio Number', field: 'folioNumber', kind: _t),
    (label: 'Issuer Name', field: 'issuerName', kind: _t),
    (label: 'Issuer Details', field: 'issuer', kind: _t),
    (label: 'Price Code', field: 'priceId', kind: _t),
    (label: 'Quantity', field: 'quantity', kind: _t),
    (label: 'Unit Value', field: 'unitValue', kind: _m),
    (label: 'Base Currency Value', field: 'amountInCollateralCurrency', kind: _m),
  ],
};

/// INVENTORY's Product Details dialog (credit-facility-inventory/hooks.js).
const List<CfColumn> cfInventoryProductColumns = [
  (label: 'Unit Value', field: 'pricePerUnit', kind: _m),
  (label: 'Product Code', field: 'productCode', kind: _t),
  (label: 'Product Description', field: 'productDescription', kind: _t),
  (label: 'Stock Quantity', field: 'stockQuantity', kind: _t),
  (label: 'Total Value', field: 'totalCost', kind: _m),
];

/// `collaterals/{id}` → `collateralDTO` (Collateral Details).
class CfCollateralDetail {
  const CfCollateralDetail({
    required this.code,
    this.type,
    this.value,
    this.limitContribution,
    this.utilization,
    this.block,
    this.available,
    this.covenants = const [],
    this.rows = const [],
  });

  final String code;
  final String? type;
  final MoneyAmount? value;
  final MoneyAmount? limitContribution;
  final MoneyAmount? utilization;

  /// 0 when missing, as OBDX sets it (hooks.js:150-152).
  final MoneyAmount? block;
  final MoneyAmount? available;
  final List<CfCovenant> covenants;

  /// `collateralDetails`. The panels bind it as a list; the page also walks
  /// it as one object (hooks.js:156-167). Either is accepted `[UNKNOWN]`.
  final List<Map<String, dynamic>> rows;

  /// The type's columns; null for a type OBDX has no panel for.
  List<CfColumn>? get columns => type == null ? null : cfCollateralColumns[type!.toUpperCase()];

  /// Money fields without their own currency use this one.
  String? get currency => available?.currency ?? value?.currency;

  static CfCollateralDetail? fromPayload(Map<String, dynamic> body, String code) {
    final d = ObdxApiUtils.asMap(body['collateralDTO']);
    if (d.isEmpty) return null;
    final details = d['collateralDetails'];
    final block = _money(d['blockAmount']);
    return CfCollateralDetail(
      code: code,
      type: _str(d['collateralType']),
      value: _money(d['collateralValue']),
      limitContribution: _money(d['limitContribution']),
      utilization: _money(d['utilizationAmount']),
      block: MoneyAmount(amount: block?.amount ?? 0, currency: block?.currency ?? _money(d['availableAmount'])?.currency),
      available: _money(d['availableAmount']),
      covenants: CfCovenant.listFrom(d['covenantDTO']),
      rows: details is Map ? [Map<String, dynamic>.from(details)] : _maps(details),
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
