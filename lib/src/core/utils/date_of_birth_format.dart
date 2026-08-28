/// Shared date-of-birth formatting for registration and forgot-credentials.
class DateOfBirthFormat {
  DateOfBirthFormat._();

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
}
