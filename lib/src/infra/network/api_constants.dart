import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/core/config/env_config.dart';

class ApiConst {
  static const String contentTypeKey = 'Content-Type';
  static const String contentTypeValue = 'application/json';
  static const String userAgentKey = 'User-Agent';
  static const String authorization = 'Authorization';
  static const String xTokenType = 'X-Token-Type';
  static const String xTargetUnit = 'X-Target-Unit';
  static const String xRequestedWith = 'X-Requested-With';
  static const String connection = 'Connection';
  static const String keepAlive = 'keep-alive';
  static const String xAuthenticationType = 'x-authentication-type';
  static const String xChallenge = 'X-Challenge';
  /// Digx-ui / OBDX OTP step-up header (Chrome capture: `X-Challenge_response`).
  /// HTTP header names are case-insensitive; keep digx casing for fidelity.
  static const String xChallengeResponse = 'X-Challenge_response';

  /// OBDX returns this when login OTP (or step-up) is required on profile.
  static const int expectationFailed = 417;

  static const String userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36';

  static String get baseUrl => EnvConfig.requireBaseUrl();

  static String get webFallbackUrl => EnvConfig.webFallbackUrl;

  /// Dio base URL: on web prefers [OBDX_WEB_FALLBACK_URL] when set (e.g. local proxy).
  static String get resolvedBaseUrl {
    if (kIsWeb && EnvConfig.obdxWebFallbackUrl.trim().isNotEmpty) {
      return EnvConfig.webFallbackUrl;
    }
    return baseUrl;
  }

  static const String publicKeyApi = '/digx-admin/security/v1/publicKey';
  static const String saltApi = '/digx-admin/security/v1/salt';

  /// Login OTP resend (digx-ui): `POST .../2fa/{referenceNo}/resend`.
  static String twoFactorResendApi(String referenceNo) =>
      '/digx-admin/security/v1/2fa/${Uri.encodeComponent(referenceNo)}/resend';

  static const String loginApi = '/digx-infra/login/v1/login';
  static const String logoutApi = '/digx-infra/login/v1/logout';
  static const String anonymousTokenApi = '/digx-infra/login/v1/anonymousToken';
  static const String accountTypesApi =
      '/digx-common/party/v1/enumerations/accountTypes';
  static const String registrationApi = '/digx-common/user/v1/registration';

  /// Header that carries the registration verification code (OTP).
  /// digx-ui sends this as `Token_id` (not `Token`).
  static const String registrationTokenHeader = 'Token_id';

  static String registrationAuthenticationApi(String registrationId) =>
      '$registrationApi/$registrationId/authentication';

  /// Step 3 — creates the login username/password for a verified
  /// registration: `POST .../registration/{id}/credentials`.
  static String registrationCredentialsApi(String registrationId) =>
      '$registrationApi/$registrationId/credentials';

  static const String profileApi = '/digx-common/user/v1/me';
  static const String mobileClientApi = '/digx-infra/mobile/v1/mobileClient';
  static const String jwtSetupApi = '/digx-admin/sms/v1/jwt';
  static const String forgotUserIdApi =
      '/digx-admin/sms/v1/credentials/forgotUserId';
  static const String forgotCredentialsApi =
      '/digx-admin/sms/v1/credentials/forgotCredentials';

  /// OBDX mobile access point for JWT setup token (step 5). Override via `OBDX_JWT_ACCESS_POINT_ID`.
  static String get accessPointId => EnvConfig.jwtAccessPointId;
  /// Legacy POC CASA list (not used by current Offshore collection).
  static const String accountsApiCz =
      '/digx-common/account/cz/v1/czaccounts?accountCode=ALL';

  /// CASA list per Offshore Postman `11_Accounts` / OBDX API Reference V1.1.
  /// Query: `accountType=CURRENT,SAVING&status=ACTIVE&status=DORMANT`.
  static const String accountsApiDemandDeposit =
      '/digx-common/dda/v1/demandDeposit';

  /// CASA account detail: `GET …/demandDeposit/{accountId}`.
  static String demandDepositAccountApi(String accountId) =>
      '$accountsApiDemandDeposit/${Uri.encodeComponent(accountId)}';

  /// CASA transactions: `GET …/demandDeposit/{accountId}/transactions`.
  static String demandDepositTransactionsApi(String accountId) =>
      '$accountsApiDemandDeposit/${Uri.encodeComponent(accountId)}/transactions';

  /// Statement media types enumeration.
  static const String demandDepositMediaTypeApi =
      '/digx-common/dda/v1/enumerations/mediatype';

  /// Bank current date (statement date pickers).
  static const String commonCurrentDateApi =
      '/digx-common/common/v1/currentDate';

  /// Loan / finance list — Postman Balance Overview.
  static const String loanApi = '/digx-common/loan/v1/loan';

  /// Single loan account details — confirmed against OBDX retail loan
  /// screens capture: `GET /digx-common/loan/v1/loan/{id}?module=CON`.
  static String loanDetailsApi(String loanId) =>
      '/digx-common/loan/v1/loan/${Uri.encodeComponent(loanId)}';

  /// Loan transaction history — same `searchBy=LNT`/`noOfTransactions`
  /// convention as the CASA transactions endpoint.
  /// `GET /digx-common/loan/v1/loan/{id}/transactions`
  static String loanTransactionsApi(String loanId) =>
      '/digx-common/loan/v1/loan/${Uri.encodeComponent(loanId)}/transactions';

  /// Loan repayment schedule — `GET .../loan/{id}/schedule?module=CON`.
  static String loanScheduleApi(String loanId) =>
      '/digx-common/loan/v1/loan/${Uri.encodeComponent(loanId)}/schedule';

  /// Loan outstanding breakdown — `GET .../loan/{id}/outstanding?module=CON`.
  static String loanOutstandingApi(String loanId) =>
      '/digx-common/loan/v1/loan/${Uri.encodeComponent(loanId)}/outstanding';

  /// Loan disbursement history — `GET .../loan/{id}/disbursements?module=CON`.
  static String loanDisbursementsApi(String loanId) =>
      '/digx-common/loan/v1/loan/${Uri.encodeComponent(loanId)}/disbursements';

  /// Loan repayment submission — `POST .../loan/{id}/repayments`.
  static String loanRepaymentsApi(String loanId) =>
      '/digx-common/loan/v1/loan/${Uri.encodeComponent(loanId)}/repayments';

  /// @deprecated Prefer [accountsApiDemandDeposit].
  static const String accountsApi = accountsApiDemandDeposit;

  static const List<String> noAuthPaths = [
    publicKeyApi,
    saltApi,
    loginApi,
    anonymousTokenApi,
    // Self-registration is fully anonymous end-to-end (keyed only by
    // registrationId) — the real digx-ui never sends an Authorization
    // header for POST registration, PUT .../authentication, or
    // POST .../credentials. `registrationApi` as a substring covers all
    // three via the `requestPath.contains(path)` check below.
    registrationApi,
    accountTypesApi,
    '/digx-ui/',
  ];

  static const List<String> noTargetUnitPaths = [
    profileApi,
  ];
}