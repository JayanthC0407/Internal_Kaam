import 'package:demo_bank/src/core/models/common/money_amount.dart';
import 'package:demo_bank/src/core/models/common/obdx_batch.dart';
import 'package:demo_bank/src/infra/network/obdx_api_utils.dart';

/// Liquidity Management ▸ Overview (corporate): the `liquidity-management`
/// module dashboard's widgets (`components/widgets/liquidity-management/`).
/// Shapes and rules from the OBDX source and its design-dashboard samples:
/// docs/obdx/features/liquidity-management.md §2-§9.

/// The Overview's widgets by OBDX `componentName`, in
/// `moduleComponents.json` order. `notification-details` is listed there
/// but has no component in the source (card §9), so it is not built.
enum LmOverviewWidget {
  assetsAndLiabilities('assets-and-liabilities'),
  crossBorderSweeps('cross-border-sweeps'),
  positionByCurrency('position-by-currency'),
  positionByRegion('position-by-region', wide: true),
  sweepLog('sweep-log', wide: true),
  topFiveSweeps('top-five-sweeps');

  const LmOverviewWidget(this.componentName, {this.wide = false});

  final String componentName;

  /// `2x` in the widget's manifest: takes a full row on wide screens.
  final bool wide;

  /// The module dashboard's `value`.
  static const module = 'liquidity-management';

  static LmOverviewWidget? byName(String name) {
    for (final w in values) {
      if (w.componentName == name) return w;
    }
    return null;
  }

  /// The known widgets among the server layout's names, in its order;
  /// every widget when none is known.
  static List<LmOverviewWidget> fromLayout(Iterable<String> names) {
    final known = [for (final n in names) if (byName(n) case final w?) w];
    return known.isEmpty ? values : {...known}.toList();
  }
}

/// `liquidityManagement/accounts` → `liquidityManagementAccounts[]`
/// (sample `lm-accounts.json`).
class LmAccount {
  const LmAccount({
    required this.number,
    this.name,
    this.branch,
    required this.currency,
    this.country,
    this.balance = 0,
    this.external = false,
  });

  /// `accountId.displayValue`.
  final String number;

  /// `displayName`.
  final String? name;
  final String? branch;

  /// `currencyCode`.
  final String currency;
  final String? country;

  /// `currentBalance.amount`; 0 when missing, as OBDX's `|| 0`.
  final double balance;
  final bool external;

  /// The FX-rate key: `branchCode-currencyCode`.
  String get rateKey => '$branch-$currency';

  MoneyAmount get money => MoneyAmount(amount: balance, currency: currency);

  /// Accounts with neither a balance nor the external flag are skipped,
  /// as Position By Currency does.
  static List<LmAccount> listFromPayload(Map<String, dynamic> body) => [
        for (final a in _maps(body['liquidityManagementAccounts']))
          if (_str(a['currencyCode']) case final ccy?)
            if (a['currentBalance'] is Map || a['external'] == true)
              LmAccount(
                number: _str(ObdxApiUtils.asMap(a['accountId'])['displayValue']) ?? '--',
                name: _str(a['displayName']),
                branch: _str(a['branchCode']),
                currency: ccy,
                country: _str(a['country']),
                balance: _num(ObdxApiUtils.asMap(a['currentBalance'])['amount']) ?? 0,
                external: a['external'] == true,
              ),
      ];
}

/// `liquidityManagement/currencies`: the widgets read `items[].code`; the
/// sample has `currencyList[]` — both are read `[UNKNOWN]` (card §9).
List<String> lmCurrencies(Map<String, dynamic> body) => [
      for (final c in [..._maps(body['items']), ..._maps(body['currencyList'])])
        if (_str(c['code']) case final code?) code,
    ];

/// `bankConfiguration` → `bankConfigurationDTO.localCurrency`.
String? lmLocalCurrency(Map<String, dynamic> body) =>
    _str(ObdxApiUtils.asMap(body['bankConfigurationDTO'])['localCurrency']);

/// `me/party` → `party.personalDetails.fullName` (Party Name).
String? lmPartyName(Map<String, dynamic> body) =>
    _str(ObdxApiUtils.asMap(ObdxApiUtils.asMap(body['party'])['personalDetails'])['fullName']);

/// What a balance widget loads before converting.
class LmBalances {
  const LmBalances({this.accounts = const [], this.currencies = const [], this.localCurrency, this.partyName});

  final List<LmAccount> accounts;
  final List<String> currencies;
  final String? localCurrency;
  final String? partyName;

  /// The default "In Equivalent" / currency choice: the local currency.
  String? get defaultCurrency => localCurrency ?? currencies.firstOrNull;
}

/// FX rates by `branchCode-ccy1Code` → `midRate`, to one target currency.
class LmRates {
  const LmRates(this.byKey);

  static const none = LmRates({});

  final Map<String, double> byKey;

  /// One batch part per unique `branch-currency` not already in [target]
  /// (assets-and-liabilities/hooks.js:170-195).
  static List<ObdxBatchItem> requests(List<LmAccount> accounts, String target) => [
        for (final key in {for (final a in accounts) if (a.currency != target) a.rateKey})
          ObdxBatchItem(
            method: 'GET',
            uri: '/forex/rates?branchCode=${key.split('-').first}'
                '&ccy1Code=${key.split('-').skip(1).join('-')}&ccy2Code=$target',
            applicationId: 'digx-forexdeal',
          ),
      ];

  /// Each answer's `exchangeRateKey` and `exchangeRateDetails[0].midRate`.
  static LmRates fromResults(List<ObdxBatchItemResult> results) {
    final rates = <String, double>{};
    for (final r in results) {
      final key = ObdxApiUtils.asMap(r.body['exchangeRateKey']);
      final details = _maps(r.body['exchangeRateDetails']);
      final rate = details.isEmpty ? null : _num(details.first['midRate']);
      final branch = _str(key['branchCode']), ccy = _str(key['ccy1Code']);
      if (rate != null && branch != null && ccy != null) rates['$branch-$ccy'] = rate;
    }
    return LmRates(rates);
  }

  /// [a]'s balance in [target]; null when its rate is missing.
  double? convert(LmAccount a, String target) {
    if (a.currency == target) return a.balance;
    final rate = byKey[a.rateKey];
    return rate == null ? null : a.balance * rate;
  }
}

/// Position By Currency: one row per currency, balances summed without
/// conversion (position-by-currency/hooks.js:95-136).
class LmCurrencyPosition {
  const LmCurrencyPosition({required this.currency, required this.balance, required this.accounts});

  final String currency;
  final double balance;
  final List<LmAccount> accounts;

  static List<LmCurrencyPosition> group(List<LmAccount> accounts) {
    final byCurrency = <String, List<LmAccount>>{};
    for (final a in accounts) {
      byCurrency.putIfAbsent(a.currency, () => []).add(a);
    }
    return [
      for (final MapEntry(:key, :value) in byCurrency.entries)
        LmCurrencyPosition(currency: key, balance: value.fold(0, (s, a) => s + a.balance), accounts: value),
    ];
  }
}

/// Position By Region in one currency: converted totals per `country`, or
/// [missingRate] when an account's rate is missing (OBDX then clears the
/// totals and says "Exchange rate not found").
class LmRegionPositions {
  const LmRegionPositions({this.totals = const {}, this.missingRate = false});

  final Map<String, double> totals;
  final bool missingRate;

  static LmRegionPositions of(List<LmAccount> accounts, LmRates rates, String target) {
    final totals = <String, double>{};
    for (final a in accounts) {
      final country = a.country;
      if (country == null) continue;
      final v = rates.convert(a, target);
      if (v == null) return const LmRegionPositions(missingRate: true);
      totals[country] = (totals[country] ?? 0) + v;
    }
    return LmRegionPositions(totals: totals);
  }

  /// A selected country's rows: per account currency, the count and the
  /// unconverted sum.
  static List<({String currency, int count, double balance})> byCurrency(List<LmAccount> accounts, String country) {
    final rows = <String, ({int count, double balance})>{};
    for (final a in accounts.where((a) => a.country == country)) {
      final r = rows[a.currency] ?? (count: 0, balance: 0.0);
      rows[a.currency] = (count: r.count + 1, balance: r.balance + a.balance);
    }
    return [for (final MapEntry(:key, :value) in rows.entries) (currency: key, count: value.count, balance: value.balance)];
  }
}

/// Assets & Liabilities in one currency (assets-and-liabilities/hooks.js
/// 122-168): converted balances above 0 are Assets, the rest Liabilities
/// (as positive figures); Net Positions = Assets − Liabilities.
class LmAssetsLiabilities {
  const LmAssetsLiabilities({this.assets = 0, this.liabilities = 0, this.missingRate = false});

  final double assets;
  final double liabilities;
  final bool missingRate;

  double get net => assets - liabilities;

  static LmAssetsLiabilities of(List<LmAccount> accounts, LmRates rates, String target) {
    var assets = 0.0, liabilities = 0.0;
    for (final a in accounts) {
      final v = rates.convert(a, target);
      if (v == null) return const LmAssetsLiabilities(missingRate: true);
      if (v > 0) {
        assets += v;
      } else {
        liabilities -= v;
      }
    }
    return LmAssetsLiabilities(assets: assets, liabilities: liabilities);
  }

  /// The Accounts Summary modal: Assets are balances ≥ 0, largest first;
  /// Liabilities below 0, most negative first. Unconverted.
  static List<LmAccount> accountsFor(List<LmAccount> accounts, {required bool assets}) {
    final rows = accounts.where((a) => assets ? a.balance >= 0 : a.balance < 0).toList()
      ..sort((x, y) => assets ? y.balance.compareTo(x.balance) : x.balance.compareTo(y.balance));
    return rows;
  }
}

/// `structures/sweeplogs` → `sweepLogs[]` (samples `top-five-sweeps.json`,
/// `cross-border-currency.json`, `upcoming-sweeps.json`).
class LmSweepLog {
  const LmSweepLog({
    this.structureId,
    this.instructionDescription,
    this.valueDate,
    this.direction,
    this.outAccount,
    this.inAccount,
    this.outAccountName,
    this.inAccountName,
    this.outAmount,
    this.inAmount,
    this.exchangeRate,
    this.exceptionMessage,
  });

  final String? structureId;
  final String? instructionDescription;
  final DateTime? valueDate;

  /// `sweepDirection`: `OneWay` "Sweep", `TwoWay` "Reverse Sweep".
  final String? direction;
  final String? outAccount;
  final String? inAccount;

  /// Not in any sample `[UNKNOWN]`.
  final String? outAccountName;
  final String? inAccountName;
  final MoneyAmount? outAmount;
  final MoneyAmount? inAmount;
  final String? exchangeRate;
  final String? exceptionMessage;

  String get sweepType => switch (direction) {
        'OneWay' => 'Sweep',
        'TwoWay' => 'Reverse Sweep',
        _ => direction ?? '--',
      };

  static List<LmSweepLog> listFromPayload(Map<String, dynamic> body) => [
        for (final s in _maps(body['sweepLogs']))
          LmSweepLog(
            structureId: _str(s['structureId']),
            instructionDescription: _str(s['instructionDescription']),
            valueDate: s['valueDate'] == null ? null : DateTime.tryParse('${s['valueDate']}'),
            direction: _str(s['sweepDirection']),
            outAccount: _str(ObdxApiUtils.asMap(s['sweepOutAccount'])['displayValue']),
            inAccount: _str(ObdxApiUtils.asMap(s['sweepInAccount'])['displayValue']),
            outAccountName: _str(s['sweepOutAccountName']),
            inAccountName: _str(s['sweepInAccountName']),
            outAmount: s['sweepOutAmount'] == null ? null : MoneyAmount.fromJson(s['sweepOutAmount']),
            inAmount: s['sweepInAmount'] == null ? null : MoneyAmount.fromJson(s['sweepInAmount']),
            exchangeRate: _str(s['exchangeRate']),
            exceptionMessage: _str(s['exceptionMessage']),
          ),
      ];

  /// Top 5 Sweeps / Top 5 Cross Currency Sweeps: the five largest
  /// `sweepInAmount.amount`.
  static List<LmSweepLog> topFive(List<LmSweepLog> rows) =>
      ([...rows]..sort((a, b) => (b.inAmount?.amount ?? 0).compareTo(a.inAmount?.amount ?? 0))).take(5).toList();
}

/// `liquidityManagement/structures` → `structure[]{id, description}`
/// (sample `structures-list.json`): Structure Details' description.
Map<String, String> lmStructures(Map<String, dynamic> body) => {
      for (final s in _maps(body['structure']))
        if (_str(s['id']) case final id?) id: _str(s['description']) ?? '',
    };

/// Sweep Monitor's tabs: `sweepStatus` and the date window — Upcoming
/// looks a month ahead, the others a month back (sweep-log/hooks.js).
enum LmSweepStatus {
  upcoming('U', 'Upcoming'),
  pending('P', 'Pending'),
  executed('S', 'Executed'),
  exception('E', 'Exception');

  const LmSweepStatus(this.code, this.label);

  final String code;
  final String label;

  ({DateTime from, DateTime to}) window(DateTime today) => this == upcoming
      ? (from: today, to: lmMonthFrom(today, 1))
      : (from: lmMonthFrom(today, -1), to: today);
}

/// [d] moved by [months], as JavaScript's `setMonth` does (day overflow
/// rolls into the next month).
DateTime lmMonthFrom(DateTime d, int months) => DateTime(d.year, d.month + months, d.day);

/// OBDX's `dateToLocalIso` for a midnight date: `2026-10-31T00:00:00`
/// `[UNKNOWN]` (not seen in a HAR).
String lmIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';

List<Map<String, dynamic>> _maps(dynamic raw) =>
    raw is List ? [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)] : const [];

double? _num(dynamic raw) => raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');

String? _str(dynamic v) {
  if (v == null || v is Map || v is List) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}
