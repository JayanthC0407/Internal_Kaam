import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_accounts_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_auth_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_credentials_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_loan_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_login_wizard_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_payee_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_payments_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_mobile_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_registration_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_user_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';

/// Shared Dio client — single instance for all OBDX API modules.
final obdxDioClientProvider = Provider<ObdxDioClient>(
  (_) => ObdxDioClient.instance,
);

final obdxAuthApiProvider = Provider(
  (ref) => ObdxAuthApi(ref.watch(obdxDioClientProvider)),
);

final obdxUserApiProvider = Provider(
  (ref) => ObdxUserApi(ref.watch(obdxDioClientProvider)),
);

final obdxRegistrationApiProvider = Provider(
  (ref) => ObdxRegistrationApi(ref.watch(obdxDioClientProvider)),
);

final obdxCredentialsApiProvider = Provider(
  (ref) => ObdxCredentialsApi(ref.watch(obdxDioClientProvider)),
);

final obdxAccountsApiProvider = Provider(
  (ref) => ObdxAccountsApi(ref.watch(obdxDioClientProvider)),
);

final obdxLoanApiProvider = Provider(
  (ref) => ObdxLoanApi(ref.watch(obdxDioClientProvider)),
);

final obdxMobileApiProvider = Provider(
  (ref) => ObdxMobileApi(ref.watch(obdxDioClientProvider)),
);

final obdxPayeeApiProvider = Provider(
  (ref) => ObdxPayeeApi(ref.watch(obdxDioClientProvider)),
);

/// First-time Login Flow Wizard (LFW) — ported from vendor branch.
final obdxLoginWizardApiProvider = Provider(
  (ref) => ObdxLoginWizardApi(ref.watch(obdxDioClientProvider)),
);

/// Own-account transfer — ported from vendor branch.
final obdxPaymentsApiProvider = Provider(
  (ref) => ObdxPaymentsApi(ref.watch(obdxDioClientProvider)),
);
