/// Shared date-of-birth formatting for registration and forgot-credentials.
class DateOfBirthFormat {
  DateOfBirthFormat._();

  static const int maxDigitCount = 8;
  static const int displayTextLength = 10; // dd/MM/yyyy

  /// API payload format: `YYYY-MM-DD`.
  static String toApi(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Display format: `dd/MM/yyyy`.
  static String toDisplay(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  /// Formats up to 8 digits as partial or full `dd/MM/yyyy`.
  static String formatDigits(String rawDigits) {
    final digits = rawDigits.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.length <= 2) return digits;
    if (digits.length <= 4) {
      return '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    final capped = digits.length > maxDigitCount
        ? digits.substring(0, maxDigitCount)
        : digits;
    return '${capped.substring(0, 2)}/${capped.substring(2, 4)}/${capped.substring(4)}';
  }

  /// Parses complete display text `dd/MM/yyyy`; returns null if invalid.
  static DateTime? parseDisplay(String? text) {
    final trimmed = text?.trim() ?? '';
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1900) {
      return null;
    }

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  /// Validates user-facing DOB text for forms.
  static String? validateDisplay(
    String? text, {
    required String requiredMessage,
    required String invalidMessage,
    DateTime? maxDate,
  }) {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) return requiredMessage;
    if (trimmed.length < displayTextLength) return invalidMessage;

    final date = parseDisplay(trimmed);
    if (date == null || !isAllowedBirthDate(date, maxDate: maxDate)) {
      return invalidMessage;
    }
    return null;
  }

  static bool isAllowedBirthDate(DateTime date, {DateTime? maxDate}) {
    final max = maxDate ?? DateTime.now();
    final latest = DateTime(max.year, max.month, max.day);
    final candidate = DateTime(date.year, date.month, date.day);
    if (candidate.isAfter(latest)) return false;
    if (date.year < 1900) return false;
    return true;
  }
}
