import 'dart:convert';

import 'package:demo_bank/src/core/models/common/money_amount.dart';
import 'package:demo_bank/src/infra/network/obdx_api_utils.dart';

/// Liquidity Management ▸ Charges Inquiry (corporate). Shapes and rules
/// from the OBDX source `components/liquidity-management/lm-charges-inquiry`
/// (docs/obdx/features/liquidity-management.md §10). No sample responses
/// exist; field names are from the code `[UNKNOWN]` beyond that.

/// OBDX's range limit: `maxDayInterval` is fixed at 30 and never set from
/// `LM_CHARGE_INQUIRY_MAX_PERIOD` (card §10 quirks).
const lmChargeMaxDays = 30;

/// A Charge Description or Collection Status option.
class LmOption {
  const LmOption({required this.code, required this.description});

  final String code;
  final String description;

  /// `charges/definitions` → `items[]{code, description}`.
  static List<LmOption> definitionsFrom(Map<String, dynamic> body) => _options(body['items']);

  /// `enumerations/fetchLMChargeCollectionStatus` →
  /// `enumRepresentations[0].data[]{code, description}`.
  static List<LmOption> statusesFrom(Map<String, dynamic> body) {
    final reps = body['enumRepresentations'];
    if (reps is! List || reps.isEmpty || reps.first is! Map) return const [];
    return _options((reps.first as Map)['data']);
  }

  static List<LmOption> _options(dynamic raw) => [
        for (final e in _maps(raw))
          if (_str(e['code']) case final code?) LmOption(code: code, description: _str(e['description']) ?? code),
      ];
}

/// What the form loads: the two option lists and the maintained period.
class LmChargeSetup {
  const LmChargeSetup({this.definitions = const [], this.statuses = const [], this.maintainedMaxDays});

  final List<LmOption> definitions;
  final List<LmOption> statuses;

  /// `maintenances` → `LM_CHARGE_INQUIRY_MAX_PERIOD`. Read but not applied,
  /// as in OBDX ([lmChargeMaxDays] is what counts).
  final int? maintainedMaxDays;

  /// Collection Status text: the enum's description, else the raw code.
  String statusText(String? code) {
    if (code == null) return '--';
    for (final s in statuses) {
      if (s.code == code) return s.description;
    }
    return code;
  }

  static int? maxDaysFrom(Map<String, dynamic> body) {
    for (final d in _maps(body['configurationDetails'])) {
      if (d['propertyId'] == 'LM_CHARGE_INQUIRY_MAX_PERIOD') return int.tryParse('${d['propertyValue']}');
    }
    return null;
  }
}

/// The Search form: every field optional for the query, dates required by
/// the form.
class LmChargeQuery {
  const LmChargeQuery({this.code, this.status, this.from, this.to});

  final String? code;
  final String? status;
  final DateTime? from;
  final DateTime? to;

  /// Whole days between the dates; OBDX stops when this is over 30.
  int? get days => from == null || to == null ? null : to!.difference(from!).inDays;

  bool get tooLong => (days ?? 0) > lmChargeMaxDays;

  /// OBDX's `q`: `{"criteria":[…]}`, one `EQUALS` entry per filled field,
  /// dates as `yyyy-MM-dd` (the date picker's value); null when empty
  /// (hooks.js:141-179). How the server reads the date entries is `[UNKNOWN]`.
  String? toQ() {
    final criteria = [
      if (code != null) _criterion('code', code!),
      if (status != null) _criterion('collectionStatus', status!),
      if (from != null) _criterion('fromDate', lmDate(from!)),
      if (to != null) _criterion('toDate', lmDate(to!)),
    ];
    return criteria.isEmpty ? null : jsonEncode({'criteria': criteria});
  }

  static Map<String, dynamic> _criterion(String operand, String value) =>
      {'operand': operand, 'operator': 'EQUALS', 'value': [value]};
}

/// `2026-10-31`.
String lmDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A row of `charges` → `items[]`.
class LmCharge {
  const LmCharge({
    this.fromDate,
    this.toDate,
    this.description,
    this.amount,
    this.account,
    this.accountName,
    this.collectionAmount,
    this.exchangeRate,
    this.collectionDate,
    this.collectionStatus,
    this.additionalInfo,
    this.errorDescription,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final String? description;

  /// `amount` in `currency`.
  final MoneyAmount? amount;

  /// `account.displayValue` and `accountName`.
  final String? account;
  final String? accountName;

  /// `collectionDetails.amount` in `accountCurrency`.
  final MoneyAmount? collectionAmount;
  final double? exchangeRate;
  final DateTime? collectionDate;

  /// `collectionDetails.status` (a code).
  final String? collectionStatus;
  final String? additionalInfo;
  final String? errorDescription;

  static List<LmCharge> listFromPayload(Map<String, dynamic> body) => [
        for (final c in _maps(body['items'])) LmCharge.fromJson(c),
      ];

  factory LmCharge.fromJson(Map<String, dynamic> c) {
    final collection = ObdxApiUtils.asMap(c['collectionDetails']);
    return LmCharge(
      fromDate: _date(c['fromDate']),
      toDate: _date(c['toDate']),
      description: _str(c['description']),
      amount: _amount(c['amount'], _str(c['currency'])),
      account: _str(ObdxApiUtils.asMap(c['account'])['displayValue']),
      accountName: _str(c['accountName']),
      collectionAmount: _amount(collection['amount'], _str(c['accountCurrency'])),
      exchangeRate: _num(c['exchangeRate']),
      collectionDate: _date(collection['date']),
      collectionStatus: _str(collection['status']),
      additionalInfo: _str(c['additionalInfo']),
      errorDescription: _str(collection['errorDescription']),
    );
  }

  /// OBDX passes `amount` straight to `formatCurrency`, so it is a number;
  /// an `{amount, currency}` object is accepted too `[UNKNOWN]`.
  static MoneyAmount? _amount(dynamic raw, String? currency) {
    if (raw == null) return null;
    if (raw is Map) return MoneyAmount.fromJson(raw, fallbackCurrency: currency);
    final n = _num(raw);
    return n == null ? null : MoneyAmount(amount: n, currency: currency);
  }
}

List<Map<String, dynamic>> _maps(dynamic raw) =>
    raw is List ? [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)] : const [];

DateTime? _date(dynamic raw) => raw == null ? null : DateTime.tryParse('$raw');

double? _num(dynamic raw) => raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');

String? _str(dynamic v) {
  if (v == null || v is Map || v is List) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}
