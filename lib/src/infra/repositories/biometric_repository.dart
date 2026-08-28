import 'package:flutter/foundation.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/constants/adlog.dart';
import 'package:ubci_bank/src/core/models/login_flow_result.dart';
import 'package:ubci_bank/src/core/models/login_trace.dart';
import 'package:ubci_bank/src/core/models/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/otp_login_pending.dart';
import 'package:ubci_bank/src/core/utils/jwt_utils.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_auth_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_mobile_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_user_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/security/mobile_device_info_service.dart';
import 'package:ubci_bank/src/infra/security/obdx_password_crypto_service.dart';
import 'package:ubci_bank/src/infra/security/secure_device_id_service.dart';
import 'package:ubci_bank/src/infra/session/session_manager.dart';

/// OBDX server biometric enrollment (steps 4–5) and token login (step 6).
class BiometricRepository {
  BiometricRepository({
    required ObdxAuthApi authApi,
    required ObdxMobileApi mobileApi,
    required ObdxUserApi userApi,
    required PreferenceHelper preferences,
    required SessionManager sessionManager,
    required ObdxPasswordCryptoService passwordCrypto,
  })  : _authApi = authApi,
        _mobileApi = mobileApi,
        _userApi = userApi,
        _preferences = preferences,
        _sessionManager = sessionManager,
        _passwordCrypto = passwordCrypto;

  final ObdxAuthApi _authApi;
  final ObdxMobileApi _mobileApi;
  final ObdxUserApi _userApi;
  final PreferenceHelper _preferences;
  final SessionManager _sessionManager;
  final ObdxPasswordCryptoService _passwordCrypto;

  /// Registers device + requests JWT setup token. Requires an active login session.
  Future<ResponseHandler<void>> enrollServerBiometric({
    required String userName,
    required String encryptedPassword,
    String? plainPassword,
  }) async {
    if (kIsWeb) {
      return ResponseHandler.error(
        0,
        'Biometric enrollment is not available on web.',
      );
    }
    final passwordForJwt = await _resolveJwtPassword(
      userName: userName,
      plainPassword: plainPassword,
      encryptedPassword: encryptedPassword,
    );
    if (passwordForJwt is! Success<String> || passwordForJwt.data == null) {
      return _mapFailure(passwordForJwt);
    }

    final deviceId = await SecureDeviceIdService.instance.getOrCreate();
    final deviceInfo = await MobileDeviceInfoService.instance.collect();

    final mobileResult = await _mobileApi.registerMobileClient(
      osVersion: deviceInfo.osVersion,
      os: deviceInfo.os,
      manufacturer: deviceInfo.manufacturer,
      model: deviceInfo.model,
      secureDeviceId: deviceId,
    );
    if (mobileResult is! Success<Map<String, dynamic>>) {
      if (kDebugMode) {
        adLog('mobileClient enrollment failed before /jwt');
      }
      return _mapFailure(mobileResult);
    }
    if (kDebugMode) {
      adLog('mobileClient enrollment succeeded');
    }

    final jwtResult = await _authApi.requestJwtSetupToken(
      userName: userName,
      encryptedPassword: passwordForJwt.data!,
    );
    if (jwtResult is! Success<Map<String, dynamic>> || jwtResult.data == null) {
      return _mapFailure(jwtResult);
    }

    final setupToken = ObdxAuthApi.extractBiometricSetupToken(jwtResult.data!);
    if (setupToken.isEmpty) {
      return ResponseHandler.error(
        jwtResult.code,
        'JWT setup response is missing jwtoken.',
      );
    }

    await _preferences.setBiometricSetupToken(setupToken);
    await _preferences.setBiometricServerEnrolled(true);
    // Keep pending credentials until logout so More-tab disable → re-enable
    // can request a fresh setup token without another password login.
    return ResponseHandler.success(null);
  }

  /// Attempts enrollment using credentials saved after password + OTP login.
  Future<ResponseHandler<void>> enrollServerBiometricFromPending() async {
    final pending = await _preferences.getPendingBiometricEnrollment();
    if (pending == null) {
      return ResponseHandler.error(
        0,
        'Biometric server enrollment requires a recent password login.',
      );
    }
    return enrollServerBiometric(
      userName: pending.userName,
      encryptedPassword: pending.encryptedPassword,
      plainPassword: pending.plainPassword,
    );
  }

  /// Fresh salt + RSA encrypt when plain password is available; otherwise reuse ciphertext.
  Future<ResponseHandler<String>> _resolveJwtPassword({
    required String userName,
    String? plainPassword,
    required String encryptedPassword,
  }) async {
    if (plainPassword != null && plainPassword.isNotEmpty) {
      if (kDebugMode) {
        adLog('Re-encrypting password with fresh salt for /jwt');
      }
      return _passwordCrypto.encryptForUser(
        userName: userName,
        plainPassword: plainPassword,
      );
    }

    if (kDebugMode) {
      adLog('No plain password for /jwt — reusing login ciphertext (may fail)');
    }
    return ResponseHandler.success(encryptedPassword);
  }

  /// Step 6 — exchange stored setup token for a session JWT, then load profile.
  ///
  /// [setupTokenOverride] is required when the stored token is PIN/pattern-encrypted
  /// (caller decrypts first).
  Future<ResponseHandler<LoginFlowResult>> loginWithBiometricToken({
    String? setupTokenOverride,
  }) async {
    if (kIsWeb) {
      return ResponseHandler.error(
        0,
        'Biometric login is not available on web.',
      );
    }
    final setupToken =
        setupTokenOverride ?? await _preferences.getBiometricSetupToken();
    if (setupToken == null || setupToken.isEmpty) {
      return ResponseHandler.error(0, 'Biometric setup token is missing.');
    }

    final deviceId = await SecureDeviceIdService.instance.getOrCreate();
    await _authApi.initSession();

    final loginResult = await _authApi.loginWithBiometricToken(
      setupToken: setupToken,
      deviceId: deviceId,
    );
    if (loginResult is! Success<Map<String, dynamic>> ||
        loginResult.data == null) {
      return _mapFailure(loginResult);
    }

    final loginResponse = loginResult.data!;
    final loginStatus = loginResponse['statusCode'] as int? ?? 0;
    if (loginStatus != StatusCode.OK) {
      // Keep local biometric enrollment (Grow-style). Password login renews
      // the setup token silently; do not force re-setup UI.
      final obdxError = ObdxErrorMapper.fromHttpResponse(
        loginStatus,
        loginResponse['body'] ?? loginResponse['rawBody'],
      );
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? loginStatus,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    final userName = await _sessionManager.getLastUserName() ?? 'User';
    final partialTrace = LoginTrace(
      publicKeyResponse: const {},
      saltResponse: const {},
      encryptedPassword: '',
      loginResponse: loginResponse,
      displayName: JwtUtils.extractName(
        (await _preferences.getAuthorization())?.accessToken ?? '',
      ),
    );

    final profile = await _userApi.fetchProfile();
    if (profile is! Success<Map<String, dynamic>> || profile.data == null) {
      return _mapFailure(profile);
    }

    final profileResponse = profile.data!;
    final profileStatus = profileResponse['statusCode'] as int? ?? 0;

    if (profileStatus == ApiConst.expectationFailed) {
      final challenge = ObdxChallenge.fromResponse(
        headers: profileResponse['headers'],
        body: ObdxApiUtils.asMap(
          profileResponse['body'] ?? profileResponse['rawBody'],
        ),
      );
      if (challenge == null || challenge.referenceNo.isEmpty) {
        return ResponseHandler.error(
          profileStatus,
          'Additional verification is required but challenge data is missing.',
        );
      }
      return ResponseHandler.success(
        LoginFlowResult.otpRequired(
          OtpLoginPending(
            userName: userName,
            partialTrace: LoginTrace(
              publicKeyResponse: partialTrace.publicKeyResponse,
              saltResponse: partialTrace.saltResponse,
              encryptedPassword: partialTrace.encryptedPassword,
              loginResponse: partialTrace.loginResponse,
              profileResponse: profileResponse,
              displayName: partialTrace.displayName,
            ),
            challenge: challenge,
          ),
        ),
      );
    }

    if (profileStatus != StatusCode.OK) {
      final obdxError = ObdxErrorMapper.fromProfileResponse(
        profileStatus,
        profileResponse['body'] ?? profileResponse['rawBody'],
      );
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? profileStatus,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    var displayName = partialTrace.displayName;
    final profileBody = profileResponse['body'];
    if (profileBody is Map<String, dynamic>) {
      final userProfile = profileBody['userProfile'] as Map<String, dynamic>?;
      final first = (userProfile?['firstName'] ?? '').toString().trim();
      final last = (userProfile?['lastName'] ?? '').toString().trim();
      final full = '$first $last'.trim();
      if (full.isNotEmpty) displayName = full;
    }

    await _sessionManager.onLoginSuccess(
      userName: userName,
      displayName: displayName,
    );

    return ResponseHandler.success(
      LoginFlowResult.complete(
        LoginTrace(
          publicKeyResponse: partialTrace.publicKeyResponse,
          saltResponse: partialTrace.saltResponse,
          encryptedPassword: '',
          loginResponse: loginResponse,
          profileResponse: profileResponse,
          displayName: displayName,
        ),
      ),
    );
  }

  ResponseHandler<T> _mapFailure<T>(ResponseHandler<dynamic> result) {
    if (result is Error) {
      return ResponseHandler.error(
        result.code,
        result.error,
        requestId: result.requestId,
        obdxError: result.obdxError,
      );
    }
    if (result is NetworkError) {
      return ResponseHandler.networkError(obdxError: result.obdxError);
    }
    return ResponseHandler.exceptionError();
  }
}
