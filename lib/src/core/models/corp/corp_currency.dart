import 'package:ubci_bank/src/core/models/common/money_amount.dart';

/// One entry of `GET /digx-common/common/v1/currency` (Home widgets
/// capture, entry #39) — the bank's currency master.
///
/// Used for display names only; nothing on the dashboard depends on this
/// call succeeding, so a missing entry falls back to the raw ISO code.
class CorpCurrency {
  const CorpCurrency({
    required this.code,
    this.description,
    this.type,
  });

  /// ISO code, e.g. `AED`.
  final String code;

  /// Human-readable name, e.g. `UAE Dirham`.
  final String? description;

  /// digx currency type, e.g. `PC`.
  final String? type;

  String get label {
    final name = description?.trim();
    if (name == null || name.isEmpty) return code;
    return name;
  }

  static List<CorpCurrency> listFromPayload(dynamic data) {
    final root = _unwrap(data);
    if (root == null) return const [];
    final raw = root['currencyList'] ?? root['currencies'] ?? root['items'];
    if (raw is! List) return const [];

    final parsed = <CorpCurrency>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final code = (map['code'] ?? map['currencyCode'] ?? '').toString().trim();
      if (code.isEmpty) continue;
      parsed.add(
        CorpCurrency(
          code: code.toUpperCase(),
          description: _trimmed(map['description'] ?? map['name']),
          type: _trimmed(map['type']),
        ),
      );
    }
    return parsed;
  }

  /// Code → currency, for quick lookup when labelling exposure rows.
  static Map<String, CorpCurrency> indexByCode(List<CorpCurrency> currencies) {
    return {for (final currency in currencies) currency.code: currency};
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('currencyList') ||
        map.containsKey('currencies') ||
        map.containsKey('items')) {
      return map;
    }
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }

  static String? _trimmed(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}

/// The corporate party's holding in a single currency, derived from the
/// accounts list rather than from a dedicated endpoint — OBDX computes the
/// Currency Exposure widget the same way.
class CorpCurrencyExposure {
  const CorpCurrencyExposure({
    required this.currencyCode,
    required this.total,
    required this.accountCount,
    this.label,
  });

  final String currencyCode;

  /// Net position across every account held in this currency. Negative when
  /// the party is overdrawn overall.
  final double total;

  final int accountCount;

  /// Display name from the currency master, when it resolved.
  final String? label;

  bool get isNegative => total < 0;

  /// Share of the largest absolute exposure, for the bar width. Always in
  /// `0..1`; returns 0 when there is nothing to compare against.
  double shareOf(double largestAbsolute) {
    if (largestAbsolute <= 0) return 0;
    return (total.abs() / largestAbsolute).clamp(0.0, 1.0);
  }

  MoneyAmount get amount =>
      MoneyAmount(amount: total, currency: currencyCode);
}
