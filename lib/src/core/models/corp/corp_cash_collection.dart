import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// One interval's worth of a cash-collection type (a day or a month of cash
/// withdrawals), from `GET …/cashmanagement/collections/{type}`.
///
/// **The success payload has not been captured** — both calls in the widgets
/// capture were refused by the host (`DATE006`). The reader below looks for
/// the first list of records in the body and the usual OBDX names for each
/// field; if the host names them otherwise, the entries come back empty
/// rather than wrong, and this is the one place to correct.
class CorpCashCollectionEntry {
  const CorpCashCollectionEntry({
    required this.amount,
    this.currency,
    this.date,
    this.count,
    this.channel,
  });

  final double amount;
  final String? currency;
  final DateTime? date;

  /// How many transactions the interval holds, when reported.
  final int? count;

  /// ATM, branch, … when the host splits by channel.
  final String? channel;

  static const _amountKeys = [
    'amount',
    'totalAmount',
    'transactionAmount',
    'collectionAmount',
    'value',
  ];
  static const _countKeys = [
    'count',
    'transactionCount',
    'noOfTransactions',
    'numberOfTransactions',
  ];
  static const _dateKeys = ['date', 'valueDate', 'transactionDate', 'period'];
  static const _channelKeys = [
    'channel',
    'mode',
    'transactionMode',
    'collectionMode',
    'category',
  ];

  static CorpCashCollectionEntry? fromJson(Map<String, dynamic> json) {
    final money = MoneyAmount.readFirst(json, _amountKeys, '');
    if (money == null) return null;
    return CorpCashCollectionEntry(
      amount: money.amount,
      currency: (money.currency?.isEmpty ?? true) ? null : money.currency,
      date: _first(json, _dateKeys, (v) => DateTime.tryParse(v.toString())),
      count: _first(json, _countKeys, (v) => int.tryParse(v.toString())),
      channel: _first(json, _channelKeys, (v) {
        final text = v.toString().trim();
        return text.isEmpty ? null : text;
      }),
    );
  }

  /// Every record in the first list of objects the body holds.
  static List<CorpCashCollectionEntry> listFromPayload(
    Map<String, dynamic> body,
  ) {
    for (final entry in body.entries) {
      if (entry.key == 'status') continue;
      final value = entry.value;
      if (value is List && value.every((e) => e is Map)) {
        return value
            .map((item) =>
                CorpCashCollectionEntry.fromJson(ObdxApiUtils.asMap(item)))
            .whereType<CorpCashCollectionEntry>()
            .toList();
      }
    }
    return const [];
  }

  static T? _first<T>(
    Map<String, dynamic> json,
    List<String> keys,
    T? Function(Object value) parse,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final parsed = parse(value);
      if (parsed != null) return parsed;
    }
    return null;
  }
}
