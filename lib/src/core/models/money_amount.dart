/// Monetary amount as returned by OBDX (number or `{ amount, currency }`).
///
/// Shared by both the Retail (`casa_account.dart`, `loan_account.dart`, …)
/// and Corporate (`corp/…`) model layers — every digx response carries
/// money in this same shape, so the parser lives here rather than being
/// duplicated per user type. `casa_account.dart` re-exports it so existing
/// Retail call sites keep their current import.
class MoneyAmount {
  const MoneyAmount({
    required this.amount,
    this.currency,
  });

  final double amount;
  final String? currency;

  bool get isNegative => amount < 0;

  factory MoneyAmount.fromJson(dynamic json, {String? fallbackCurrency}) {
    if (json == null) {
      return MoneyAmount(amount: 0, currency: fallbackCurrency);
    }
    if (json is num) {
      return MoneyAmount(amount: json.toDouble(), currency: fallbackCurrency);
    }
    if (json is String) {
      final parsed = double.tryParse(json.replaceAll(',', '')) ?? 0;
      return MoneyAmount(amount: parsed, currency: fallbackCurrency);
    }
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final raw = map['amount'] ?? map['value'] ?? map['availableBalance'] ?? 0;
      final amount = raw is num
          ? raw.toDouble()
          : double.tryParse(raw.toString().replaceAll(',', '')) ?? 0;
      final currency = (map['currency'] ??
              map['currencyCode'] ??
              map['currencyId'] ??
              fallbackCurrency)
          ?.toString();
      return MoneyAmount(amount: amount, currency: currency);
    }
    return MoneyAmount(amount: 0, currency: fallbackCurrency);
  }

  /// Reads the first present monetary field from [keys] on [json].
  static MoneyAmount? readFirst(
    Map<String, dynamic> json,
    List<String> keys,
    String currencyCode,
  ) {
    for (final key in keys) {
      if (!json.containsKey(key) || json[key] == null) continue;
      return MoneyAmount.fromJson(json[key], fallbackCurrency: currencyCode);
    }
    return null;
  }
}
