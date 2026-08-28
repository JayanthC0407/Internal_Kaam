extension StringExtensions on String? {
  String orEmpty() => this ?? '';

  bool isNullOrEmpty() => this == null || (this?.isEmpty ?? true);
}

extension BooleanExtensions on bool? {
  bool orFalse() => this ?? false;
}

extension DoubleExtensions on double? {
  double orZero() => this ?? 0;
}

extension IntExtensions on int? {
  int orZero() => this ?? 0;
}
