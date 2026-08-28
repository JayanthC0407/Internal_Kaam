import 'package:ubci_bank/src/core/models/token_response.dart';

/// Ephemeral anonymous JWT used only during self-registration API calls.
/// Must never be treated as a completed user login session.
class RegistrationSessionHolder {
  RegistrationSessionHolder._();

  static final RegistrationSessionHolder instance = RegistrationSessionHolder._();

  TokenResponse? _anonymousAuth;

  TokenResponse? get anonymousAuth => _anonymousAuth;

  void setAnonymous(TokenResponse token) {
    _anonymousAuth = token;
  }

  void clear() {
    _anonymousAuth = null;
  }
}
