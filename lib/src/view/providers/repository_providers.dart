import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/infra/repositories/auth_repository.dart';
import 'package:ubci_bank/src/infra/repositories/biometric_repository.dart';
import 'package:ubci_bank/src/infra/repositories/forgot_credentials_repository.dart';
import 'package:ubci_bank/src/infra/repositories/registration_repository.dart';
import 'package:ubci_bank/src/infra/repositories/payee_repository.dart';
import 'package:ubci_bank/src/infra/security/obdx_password_crypto_service.dart';
import 'package:ubci_bank/src/view/providers/network_providers.dart';
import 'package:ubci_bank/src/view/providers/session_providers.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    authApi: ref.watch(obdxAuthApiProvider),
    userApi: ref.watch(obdxUserApiProvider),
  ),
);

final registrationRepositoryProvider = Provider(
  (ref) => RegistrationRepository(
    authApi: ref.watch(obdxAuthApiProvider),
    registrationApi: ref.watch(obdxRegistrationApiProvider),
  ),
);

final forgotCredentialsRepositoryProvider = Provider(
  (ref) => ForgotCredentialsRepository(
    authApi: ref.watch(obdxAuthApiProvider),
    credentialsApi: ref.watch(obdxCredentialsApiProvider),
  ),
);

final biometricRepositoryProvider = Provider(
  (ref) => BiometricRepository(
    authApi: ref.watch(obdxAuthApiProvider),
    mobileApi: ref.watch(obdxMobileApiProvider),
    userApi: ref.watch(obdxUserApiProvider),
    preferences: ref.watch(preferenceHelperProvider),
    sessionManager: ref.watch(sessionManagerProvider),
    passwordCrypto: ObdxPasswordCryptoService(ref.watch(obdxAuthApiProvider)),
  ),
);

final payeeRepositoryProvider = Provider(
  (ref) => PayeeRepository(
    payeeApi: ref.watch(obdxPayeeApiProvider),
  ),
);
