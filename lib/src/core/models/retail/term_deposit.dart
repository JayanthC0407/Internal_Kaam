import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Retail term deposits, parsed from the OBDX TD capture (`TD.har`):
/// `GET /digx-common/td/v1/deposit` (`accounts[]` + `summary.items[]`) and
/// `GET .../deposit/{id};module=` (`termDepositDetails`).

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
}

double? _dbl(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', ''));
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _date(dynamic v) {
  final s = _str(v);
  return s == null ? null : DateTime.tryParse(s);
}

MoneyAmount? _money(dynamic v, {String? currency}) {
  final map = ObdxApiUtils.asMap(v is Map ? v : null);
  if (map.isEmpty || map['amount'] == null) return null;
  return MoneyAmount.fromJson(map, fallbackCurrency: currency);
}

/// Deposit tenure — `tenure: {days, months, years}`.
class TdTenure {
  const TdTenure({this.years = 0, this.months = 0, this.days = 0});

  final int years;
  final int months;
  final int days;

  bool get isEmpty => years == 0 && months == 0 && days == 0;

  factory TdTenure.fromJson(dynamic json) {
    final map = ObdxApiUtils.asMap(json is Map ? json : null);
    return TdTenure(
      years: _int(map['years']) ?? 0,
      months: _int(map['months']) ?? 0,
      days: _int(map['days']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() =>
      {'years': years, 'months': months, 'days': days};

  /// "1 year 3 months 10 days" — the parts that are set.
  String get label {
    String part(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final parts = [
      if (years > 0) part(years, 'year', 'years'),
      if (months > 0) part(months, 'month', 'months'),
      if (days > 0) part(days, 'day', 'days'),
    ];
    return parts.isEmpty ? '—' : parts.join(' ');
  }
}

/// The roll-over (maturity) instruction codes of
/// `GET .../td/v1/enumerations/rollOverType`.
abstract final class TdRollOver {
  /// Renew principal, pay out the interest.
  static const renewPrincipal = 'P';

  /// Renew principal and interest.
  static const renewPrincipalAndInterest = 'I';

  /// Close on maturity.
  static const closeOnMaturity = 'A';

  /// Renew a special amount, pay out the rest.
  static const renewSpecialAmount = 'S';

  /// The captured descriptions — used when the enumeration call fails.
  static const fallbackLabels = {
    renewPrincipal: 'Renew Principal and Pay Out the Interest',
    renewPrincipalAndInterest: 'Renew Principal and Interest',
    closeOnMaturity: 'Close on Maturity',
    renewSpecialAmount: 'Renew Special Amount and Pay Out the Remaining Amount',
  };

  /// Whether money leaves the deposit at maturity, so a payout account is
  /// needed: everything except "renew principal and interest".
  static bool needsPayout(String? code) =>
      code != null && code != renewPrincipalAndInterest;
}

/// One entry of an OBDX enumeration (`enumRepresentations[0].data[]`).
class TdEnumOption {
  const TdEnumOption({required this.code, required this.description});

  final String code;
  final String description;

  static List<TdEnumOption> listFromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final reps = root['enumRepresentations'];
    if (reps is! List || reps.isEmpty) return const [];
    final items = ObdxApiUtils.asMap(reps.first)['data'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map)
          if (_str(item['code']) case final code?)
            TdEnumOption(
              code: code,
              description: _str(item['description']) ?? code,
            ),
    ];
  }
}

/// One payout instruction — where principal (`P`) or interest (`I`) goes
/// at maturity (`GET .../payOutInstructions` → `payOutInstructions[]`).
class TdPayoutInstruction {
  const TdPayoutInstruction({
    this.type,
    this.percentage,
    this.componentType,
    this.account,
    this.accountDisplay,
    this.branchId,
    this.beneficiaryName,
    this.bankName,
  });

  /// Payout option: `O` own account, `I` internal, `E` domestic,
  /// `INT` international.
  final String? type;
  final double? percentage;

  /// `P` principal, `I` interest.
  final String? componentType;

  /// The raw OBDX account reference, e.g. `000@~000000788014`.
  final String? account;
  final String? accountDisplay;
  final String? branchId;
  final String? beneficiaryName;
  final String? bankName;

  /// The account to show: its display value, else the number at the end of
  /// [account] (after OBDX's `branch@~` prefix), masked to the last four.
  String get accountLabel {
    if (accountDisplay != null) return accountDisplay!;
    final raw = account;
    if (raw == null) return '—';
    final number = raw.contains('@~') ? raw.split('@~').last : raw;
    if (number.length <= 4) return number;
    return '••${number.substring(number.length - 4)}';
  }

  factory TdPayoutInstruction.fromJson(Map<String, dynamic> json) {
    final accountId = ObdxApiUtils.asMap(json['accountId']);
    return TdPayoutInstruction(
      type: _str(json['type']),
      percentage: _dbl(json['percentage']),
      componentType: _str(json['payoutComponentType']),
      account: _str(json['account']),
      accountDisplay: _str(accountId['displayValue']),
      branchId: _str(json['branchId']),
      beneficiaryName: _str(json['beneficiaryName']),
      bankName: _str(json['bankName']),
    );
  }

  static List<TdPayoutInstruction> listFromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final list = root['payOutInstructions'] ?? root['payoutInstructions'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map)
          TdPayoutInstruction.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}

/// One term deposit.
class TermDeposit {
  const TermDeposit({
    required this.id,
    required this.displayNumber,
    required this.currencyCode,
    this.status,
    this.module,
    this.holderName,
    this.partyName,
    this.partyDisplay,
    this.branchCode,
    this.branchName,
    this.holdingPattern,
    this.openingDate,
    this.valueDate,
    this.maturityDate,
    this.principalAmount,
    this.currentPrincipalAmount,
    this.maturityAmount,
    this.availableBalance,
    this.holdAmount,
    this.interestRate,
    this.tenure = const TdTenure(),
    this.rollOverType,
    this.productName,
    this.payoutInstructions = const [],
  });

  /// The encrypted OBDX id (`id.value`) used in every URL.
  final String id;

  /// The masked number (`id.displayValue`, e.g. `xxxxxxxxxxxx8078`).
  final String displayNumber;
  final String currencyCode;
  final String? status;

  /// `CON` (conventional) or `ISL` (Islamic).
  final String? module;
  final String? holderName;
  final String? partyName;
  final String? partyDisplay;
  final String? branchCode;
  final String? branchName;
  final String? holdingPattern;
  final DateTime? openingDate;
  final DateTime? valueDate;
  final DateTime? maturityDate;

  /// The amount first deposited.
  final MoneyAmount? principalAmount;

  /// The principal now, after top-ups and partial redemptions.
  final MoneyAmount? currentPrincipalAmount;
  final MoneyAmount? maturityAmount;
  final MoneyAmount? availableBalance;
  final MoneyAmount? holdAmount;
  final double? interestRate;
  final TdTenure tenure;

  /// Maturity instruction — see [TdRollOver].
  final String? rollOverType;
  final String? productName;

  /// Payout instructions carried on the deposit itself (often empty — the
  /// separate `payOutInstructions` call has them).
  final List<TdPayoutInstruction> payoutInstructions;

  bool get isActive => (status ?? 'ACTIVE').toUpperCase() == 'ACTIVE';
  bool get isClosed => (status ?? '').toUpperCase() == 'CLOSED';

  /// The deposit's current value: current principal, else available
  /// balance, else original principal.
  MoneyAmount? get currentValue =>
      currentPrincipalAmount ?? availableBalance ?? principalAmount;

  /// Last four digits of [displayNumber], e.g. `8078`.
  String get lastFour {
    final digits = displayNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) return digits.substring(digits.length - 4);
    return displayNumber;
  }

  /// "Term Deposit ••8078" style title.
  String get title => productName ?? 'Term Deposit ••$lastFour';

  /// Days from [today] to maturity; negative once matured.
  int? daysToMaturity(DateTime today) {
    final m = maturityDate;
    if (m == null) return null;
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(m.year, m.month, m.day);
    return b.difference(a).inDays;
  }

  factory TermDeposit.fromJson(Map<String, dynamic> json) {
    final idMap = ObdxApiUtils.asMap(json['id']);
    final party = ObdxApiUtils.asMap(json['partyId']);
    final branch = ObdxApiUtils.asMap(json['branchAddressDTO']);
    final product = ObdxApiUtils.asMap(json['productDTO']);
    final currency = _str(json['currencyCode']) ??
        _str(ObdxApiUtils.asMap(json['principalAmount'])['currency']) ??
        '';
    return TermDeposit(
      id: _str(idMap['value']) ?? _str(json['accountId']) ?? '',
      displayNumber: _str(idMap['displayValue']) ?? '',
      currencyCode: currency,
      status: _str(json['status']),
      module: _str(json['module']),
      holderName: _str(json['displayName']) ?? _str(json['partyName']),
      partyName: _str(json['partyName']),
      partyDisplay: _str(party['displayValue']),
      branchCode: _str(json['branchCode']),
      branchName: _str(branch['branchName']),
      holdingPattern: _str(json['holdingPattern']),
      openingDate: _date(json['openingDate']) ?? _date(json['depositDate']),
      valueDate: _date(json['valueDate']),
      maturityDate: _date(json['maturityDate']),
      principalAmount: _money(json['principalAmount'], currency: currency),
      currentPrincipalAmount:
          _money(json['currentPrincipalAmount'], currency: currency),
      maturityAmount: _money(json['maturityAmount'], currency: currency),
      availableBalance: _money(json['availableBalance'], currency: currency),
      holdAmount: _money(json['holdAmount'], currency: currency),
      interestRate: _dbl(json['interestRate']),
      tenure: TdTenure.fromJson(json['tenure']),
      rollOverType: _str(json['rollOverType']),
      productName: _str(product['name']) ?? _str(product['description']),
      payoutInstructions: [
        for (final p in (json['payoutInstructions'] is List
            ? json['payoutInstructions'] as List
            : const []))
          if (p is Map)
            TdPayoutInstruction.fromJson(Map<String, dynamic>.from(p)),
      ],
    );
  }

  /// `GET .../deposit/{id};module=` → `termDepositDetails`.
  static TermDeposit? fromDetailPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final dto = ObdxApiUtils.asMap(root['termDepositDetails']);
    if (dto.isEmpty) return null;
    return TermDeposit.fromJson(dto);
  }

  static List<TermDeposit> listFromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final list = root['accounts'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map) TermDeposit.fromJson(Map<String, dynamic>.from(item)),
    ].where((d) => d.id.isNotEmpty).toList();
  }
}

/// Totals for one currency across the customer's deposits.
class TdCurrencyTotals {
  const TdCurrencyTotals({
    required this.currency,
    required this.count,
    required this.invested,
    required this.maturity,
  });

  final String currency;
  final int count;

  /// Sum of the deposits' current values.
  final double invested;

  /// Sum of their maturity amounts.
  final double maturity;

  /// Interest the deposits are set to earn.
  double get expectedInterest => maturity - invested;
}

/// The TD list with totals by currency.
class TermDepositsSummary {
  const TermDepositsSummary({required this.deposits, required this.totals});

  final List<TermDeposit> deposits;

  /// By currency, the customer's main currency (most deposits) first.
  final List<TdCurrencyTotals> totals;

  List<TermDeposit> get active => deposits.where((d) => d.isActive).toList();
  List<TermDeposit> get closed => deposits.where((d) => d.isClosed).toList();

  /// Totals are summed from the active deposits rather than read from
  /// `summary.items`: the host's summary mixes in the closed / dormant /
  /// Islamic buckets per party, and summing what the list shows keeps the
  /// banner consistent with it.
  factory TermDepositsSummary.fromDeposits(List<TermDeposit> deposits) {
    final byCurrency = <String, List<TermDeposit>>{};
    for (final d in deposits.where((d) => d.isActive)) {
      byCurrency.putIfAbsent(d.currencyCode, () => []).add(d);
    }
    final totals = [
      for (final MapEntry(key: currency, value: list) in byCurrency.entries)
        TdCurrencyTotals(
          currency: currency,
          count: list.length,
          invested: list.fold(0, (s, d) => s + (d.currentValue?.amount ?? 0)),
          maturity: list.fold(
            0,
            (s, d) =>
                s + (d.maturityAmount?.amount ?? d.currentValue?.amount ?? 0),
          ),
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return TermDepositsSummary(deposits: deposits, totals: totals);
  }

  factory TermDepositsSummary.fromPayload(dynamic data) =>
      TermDepositsSummary.fromDeposits(TermDeposit.listFromPayload(data));
}
