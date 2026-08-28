/// Formats monetary amounts for dashboard and account display.
class MoneyFormat {
  MoneyFormat._();

  static String format(
    double amount, {
    required String currencyCode,
    bool hidden = false,
  }) {
    if (hidden) return '******';
    final raw = currencyCode.trim();
    final code = raw.isEmpty ? 'GBP' : raw.toUpperCase();
    final fixed = amount.toStringAsFixed(2);
    final withSeparators = _withThousands(fixed);
    return '$code $withSeparators';
  }

  static String _withThousands(String fixed) {
    final parts = fixed.split('.');
    final whole = parts.first;
    final fraction = parts.length > 1 ? parts[1] : '00';
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final fromEnd = whole.length - i;
      buffer.write(whole[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
    }
    return '${buffer.toString()}.$fraction';
  }
}
