/// Shared email format checks for registration and recovery flows.
class EmailValidator {
  EmailValidator._();

  static final RegExp _pattern = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );

  static bool isValid(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    return _pattern.hasMatch(trimmed);
  }
}
