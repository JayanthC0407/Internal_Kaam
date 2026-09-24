/// Shared password/username policy for the registration "create credentials"
/// step. Mirrors common OBDX defaults (min length 8, upper/lower/digit/
/// special char, must not contain the username). Kept in one place so the
/// checklist widget and form validator can never drift apart.
class PasswordPolicy {
  PasswordPolicy._();

  static const int minLength = 8;
  static const int maxLength = 20;

  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _special = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]/\\+=~`]');

  /// Username: 6-50 chars, letters/numbers/`. _ -`, must start with a letter
  /// or number.
  static final RegExp usernamePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{5,49}$');

  static bool isUsernameValid(String value) => usernamePattern.hasMatch(value.trim());

  static bool hasMinLength(String value) =>
      value.length >= minLength && value.length <= maxLength;
  static bool hasUppercase(String value) => _upper.hasMatch(value);
  static bool hasLowercase(String value) => _lower.hasMatch(value);
  static bool hasDigit(String value) => _digit.hasMatch(value);
  static bool hasSpecialChar(String value) => _special.hasMatch(value);

  /// Case-insensitive substring check so `password` can't just be the
  /// username with a couple of digits appended.
  static bool doesNotContainUsername(String password, String username) {
    final trimmedUser = username.trim();
    if (trimmedUser.isEmpty) return true;
    return !password.toLowerCase().contains(trimmedUser.toLowerCase());
  }

  static bool isPasswordValid(String password, {required String username}) {
    return hasMinLength(password) &&
        hasUppercase(password) &&
        hasLowercase(password) &&
        hasDigit(password) &&
        hasSpecialChar(password) &&
        doesNotContainUsername(password, username);
  }
}
