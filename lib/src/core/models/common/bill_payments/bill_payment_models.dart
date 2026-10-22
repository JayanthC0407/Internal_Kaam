import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Bill Payment History — OBDX `components/bill-payments/payment-history`.
/// Field mapping and rules: docs/obdx/features/bill-payments.md §5.

/// `paymentStatus` (nls payment-history.js:79-83).
enum BillPaymentStatus {
  sent('SNT'),
  completed('COM'),
  pending('PND'),
  timeout('TOT'),
  error('ERR'),
  unknown('');

  const BillPaymentStatus(this.code);

  final String code;

  static BillPaymentStatus fromCode(dynamic raw) {
    final code = (raw ?? '').toString().trim().toUpperCase();
    for (final s in values) {
      if (s != unknown && s.code == code) return s;
    }
    return unknown;
  }
}

/// One `billPaymentDTOs[]` row, read the way OBDX does (hooks.js:321-338).
class BillPayment {
  const BillPayment({
    required this.referenceNo,
    this.paymentDate,
    this.billerName,
    this.category,
    this.amount,
    this.status = BillPaymentStatus.unknown,
    this.rawStatus,
    this.attachmentId,
  });

  /// `id` — OBDX's "Reference No".
  final String referenceNo;
  final DateTime? paymentDate;

  /// `billerRegistration.billerNickName`, else `billerName`.
  final String? billerName;

  /// `billerRegistration.category.name`, else `category`.
  final String? category;
  final MoneyAmount? amount;
  final BillPaymentStatus status;

  /// The code as sent, for statuses OBDX's labels don't cover.
  final String? rawStatus;

  /// `attachmentId.value` — a receipt OBDX can download (not built yet).
  final String? attachmentId;

  static BillPayment? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = ObdxApiUtils.asMap(json);
    final id = _str(map['id']);
    if (id == null) return null;
    final registration = ObdxApiUtils.asMap(map['billerRegistration']);
    final hasRegistration = map['billerRegistration'] is Map;
    final category = map['category'];
    return BillPayment(
      referenceNo: id,
      paymentDate: DateTime.tryParse(_str(map['paymentDate']) ?? ''),
      billerName: hasRegistration ? _str(registration['billerNickName']) : _str(map['billerName']),
      category: hasRegistration
          ? _str(ObdxApiUtils.asMap(registration['category'])['name'])
          // `category` is a plain string here in OBDX's code; tolerate a map.
          : (category is Map ? _str(ObdxApiUtils.asMap(category)['name']) : _str(category)),
      amount: map['billAmount'] == null ? null : MoneyAmount.fromJson(map['billAmount']),
      status: BillPaymentStatus.fromCode(map['paymentStatus']),
      rawStatus: _str(map['paymentStatus']),
      attachmentId: _str(ObdxApiUtils.asMap(map['attachmentId'])['value']),
    );
  }

  /// Body of `GET ebillPayments`: `{ billPaymentDTOs: [...] }`, newest
  /// first like OBDX (hooks.js:363). Rows without a date go last.
  static List<BillPayment> listFromPayload(Map<String, dynamic> body) {
    final items = body['billPaymentDTOs'];
    if (items is! List) return const [];
    final list = items.map(fromJson).whereType<BillPayment>().toList()
      ..sort((a, b) {
        final da = a.paymentDate, db = b.paymentDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    return list;
  }
}

/// "Select Period" (hooks.js:248-264; nls:73-76).
enum BillHistoryPeriod {
  currentPeriod('CPR'),
  previousMonth('L1M'),
  previousQuarter('LQT'),
  dateRange('SPD');

  const BillHistoryPeriod(this.searchBy);

  final String searchBy;
}

/// The `GET ebillPayments` search. OBDX sends `searchBy`, plus
/// `fromDate`/`toDate` only for Date Range (hooks.js:474-485).
class BillHistoryQuery {
  const BillHistoryQuery({this.period = BillHistoryPeriod.currentPeriod, this.from, this.to});

  final BillHistoryPeriod period;
  final DateTime? from;
  final DateTime? to;

  bool get isComplete => period != BillHistoryPeriod.dateRange || (from != null && to != null);

  Map<String, dynamic> toQueryParameters() => {
        'searchBy': period.searchBy,
        if (period == BillHistoryPeriod.dateRange && from != null && to != null) ...{
          'fromDate': formatEbppDate(from!),
          'toDate': formatEbppDate(to!),
        },
      };

  @override
  bool operator ==(Object other) =>
      other is BillHistoryQuery && other.period == period && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(period, from, to);
}

/// Date format for `fromDate`/`toDate`. [UNKNOWN] until a UAT capture shows
/// it: OBDX passes the oj-input-date value, assumed `YYYY-MM-DD` (the same
/// shape the account transactions send). Change only here if the HAR differs.
String formatEbppDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String? _str(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
