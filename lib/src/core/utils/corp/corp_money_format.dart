import 'package:ubci_bank/src/core/models/common/money_amount.dart';

/// Money formatting for the corporate dashboard.
///
/// Differs from the Retail `MoneyFormat` in two ways the design requires:
///  - the sign leads the whole value (`-AED 1,000.00`, not `AED -1,000.00`),
///    because the Account Summary grid colours negative balances red and the
///    minus has to read before the currency;
///  - there is no hard-coded currency fallback — a missing currency code
///    renders the amount alone rather than mislabelling it.
class CorpMoneyFormat {
  CorpMoneyFormat._();

  static const String maskedValue = '••••';

  /// `AED 1,049,601.58` / `-AED 1,000.00`.
  static String format(
    double amount, {
    String? currencyCode,
    int decimalDigits = 2,
  }) {
    final code = currencyCode?.trim().toUpperCase() ?? '';
    final isNegative = amount < 0;
    final magnitude = amount.abs().toStringAsFixed(decimalDigits);
    final grouped = _withThousands(magnitude);
    final sign = isNegative ? '-' : '';
    if (code.isEmpty) return '$sign$grouped';
    return '$sign$code $grouped';
  }

  /// [format] for a [MoneyAmount], falling back to [fallbackCurrency] when
  /// the amount carries no currency of its own. Returns [placeholder] when
  /// there is no amount at all.
  static String formatAmount(
    MoneyAmount? money, {
    String? fallbackCurrency,
    String placeholder = '—',
    int decimalDigits = 2,
  }) {
    if (money == null) return placeholder;
    return format(
      money.amount,
      currencyCode: money.currency ?? fallbackCurrency,
      decimalDigits: decimalDigits,
    );
  }

  /// Balance hidden behind the card's eye toggle — keeps the currency
  /// visible so the card does not reflow when toggled.
  static String masked(String? currencyCode) {
    final code = currencyCode?.trim().toUpperCase() ?? '';
    return code.isEmpty ? maskedValue : '$code $maskedValue';
  }

  static String _withThousands(String fixed) {
    final parts = fixed.split('.');
    final whole = parts.first;
    final fraction = parts.length > 1 ? parts[1] : '';
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final fromEnd = whole.length - i;
      buffer.write(whole[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
    }
    return fraction.isEmpty ? buffer.toString() : '${buffer.toString()}.$fraction';
  }
}
