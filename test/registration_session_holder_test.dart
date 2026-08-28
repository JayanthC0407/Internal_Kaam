import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/token_response.dart';
import 'package:ubci_bank/src/infra/session/registration_session_holder.dart';

void main() {
  tearDown(RegistrationSessionHolder.instance.clear);

  test('anonymous registration token is kept in memory only', () {
    final holder = RegistrationSessionHolder.instance;
    expect(holder.anonymousAuth, isNull);

    holder.setAnonymous(
      TokenResponse(accessToken: 'anon-jwt', tokenType: 'Bearer'),
    );

    expect(holder.anonymousAuth?.accessToken, 'anon-jwt');

    holder.clear();
    expect(holder.anonymousAuth, isNull);
  });
}
