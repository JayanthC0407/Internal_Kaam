import 'package:flutter/foundation.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:pointycastle/export.dart';
import 'package:ubci_bank/src/core/models/login_body.dart';
import 'package:ubci_bank/src/core/models/login_flow_result.dart';
import 'package:ubci_bank/src/core/models/login_trace.dart';
import 'package:ubci_bank/src/core/models/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/otp_login_pending.dart';
import 'package:ubci_bank/src/core/models/token_response.dart';
import 'package:ubci_bank/src/core/utils/jwt_utils.dart';
import 'package:ubci_bank/src/core/utils/rsa_crypto_utils.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_auth_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_user_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/session/registration_session_holder.dart';

class AuthRepository {
  AuthRepository({
    required ObdxAuthApi authApi,
    required ObdxUserApi userApi,
  })  : _authApi = authApi,
        _userApi = userApi;

  final ObdxAuthApi _authApi;
  final ObdxUserApi _userApi;

  static bool get _enableWebTempAuthBypass {
    if (!kDebugMode || !kIsWeb) return false;
    return const bool.fromEnvironment('WEB_TEMP_AUTH_BYPASS',
        defaultValue: false);
  }

  Future<ResponseHandler<LoginFlowResult>> performLogin({
    required String userName,
    required String password,
  }) {
    return _performLogin(LoginBody(userName: userName, password: password));
  }

  Future<ResponseHandler<LoginTrace>> submitLoginOtp({
    required OtpLoginPending pending,
    required String otp,
  }) async {
    try {
      final profile = await _userApi.submitLoginOtp(
        challenge: pending.challenge,
        otp: otp.trim(),
      );
      if (profile is! Success<Map<String, dynamic>> || profile.data == null) {
        return _mapFailure(profile);
      }

      final profileResponse = profile.data!;
      final statusCode = profileResponse['statusCode'] as int? ?? 0;

      if (statusCode == ApiConst.expectationFailed) {
        final updated = ObdxChallenge.fromResponseHeaders(
          profileResponse['headers'],
        );
        if (updated != null) {
          pending.updateChallenge(updated);
        }
        final body = profileResponse['body'] ?? profileResponse['rawBody'];
        // Prefer challenge-aware mapping so DIGX_TFA_* / server detail is shown.
        final obdxError = ObdxErrorMapper.fromChallengeResponse(
          statusCode,
          body,
        );
        return ResponseHandler.error(
          obdxError.httpStatusCode ?? statusCode,
          obdxError.userMessage,
          obdxError: obdxError,
        );
      }

      if (statusCode != StatusCode.OK) {
        final obdxError = ObdxErrorMapper.fromProfileResponse(
          statusCode,
          profileResponse['body'] ?? profileResponse['rawBody'],
        );
        return ResponseHandler.error(
          obdxError.httpStatusCode ?? statusCode,
          obdxError.userMessage,
          obdxError: obdxError,
        );
      }

      RegistrationSessionHolder.instance.clear();
      return _completeLoginTrace(
        pending.partialTrace,
        profileResponse: profileResponse,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Resend login OTP using digx-ui `POST .../2fa/{referenceNo}/resend`.
  Future<ResponseHandler<void>> resendLoginOtp({
    required OtpLoginPending pending,
  }) async {
    try {
      final referenceNo = pending.challenge.referenceNo.trim();
      if (referenceNo.isEmpty) {
        return ResponseHandler.exceptionError();
      }

      final result = await _authApi.resendTwoFactorOtp(referenceNo: referenceNo);
      if (result is! Success<Map<String, dynamic>> || result.data == null) {
        return _mapFailure(result);
      }

      final wrapped = result.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final headers = wrapped['headers'];
      final body = ObdxApiUtils.asMap(wrapped['body']);
      final rawBody = wrapped['body'] ?? wrapped['rawBody'];

      if (statusCode != StatusCode.OK ||
          ObdxApiUtils.hasErrorMessage(body) ||
          !ObdxApiUtils.isSuccessfulPayload(body)) {
        final obdxError = ObdxErrorMapper.fromChallengeResponse(
          statusCode == 0 ? StatusCode.BAD_REQUEST : statusCode,
          rawBody,
        );
        return ResponseHandler.error(
          obdxError.httpStatusCode ?? statusCode,
          obdxError.userMessage,
          obdxError: obdxError,
        );
      }

      final updated = ObdxChallenge.fromResponseHeaders(headers);
      if (updated != null && updated.referenceNo.isNotEmpty) {
        pending.updateChallenge(updated);
      }

      return ResponseHandler.success(null);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<LoginFlowResult>> _performLogin(
    LoginBody loginBody,
  ) async {
    RegistrationSessionHolder.instance.clear();

    try {
      await PreferenceHelper.getInstance().clearSession();
      await _authApi.initSession();

      final publicKeyResult = await _authApi.getPublicKey();
      if (publicKeyResult is! Success<Map<String, dynamic>> ||
          publicKeyResult.data == null) {
        return _mapFailure(publicKeyResult);
      }

      final saltResult = await _authApi.getSalt(loginBody.userName);
      if (saltResult is! Success<Map<String, dynamic>> ||
          saltResult.data == null) {
        return _mapFailure(saltResult);
      }

      final publicKeyDTO =
          publicKeyResult.data!['publicKeyDTO'] as Map<String, dynamic>?;
      final saltDTO = saltResult.data!['saltDTO'] as Map<String, dynamic>?;
      final salt =
          (saltDTO?['id'] as String?) ?? _authApi.extractSalt(saltResult.data!);

      final RSAPublicKey rsaKey;
      final modulusHex = publicKeyDTO?['modulus'] as String?;
      final exponentHex = publicKeyDTO?['publicExponent'] as String?;
      if (modulusHex != null && exponentHex != null) {
        rsaKey = RsaCryptoUtils.buildPublicKeyFromHex(modulusHex, exponentHex);
      } else {
        final publicKeyStr = (publicKeyDTO?['publicKey'] as String?) ??
            _authApi.extractPublicKey(publicKeyResult.data!);
        rsaKey = RsaCryptoUtils.parsePublicKeyPem(publicKeyStr);
      }

      final encryptedPassword =
          RsaCryptoUtils.encryptPassword(rsaKey, loginBody.password);

      final loginResult = await _authApi.login(
        userName: loginBody.userName,
        encryptedPassword: encryptedPassword,
      );
      if (loginResult is! Success<Map<String, dynamic>> ||
          loginResult.data == null) {
        return _mapFailure(loginResult);
      }

      final loginResponse = loginResult.data!;
      final loginStatusCode = loginResponse['statusCode'] as int? ?? 0;
      if (loginStatusCode == 423) {
        final obdxError = ObdxErrorMapper.fromHttpResponse(
          loginStatusCode,
          loginResponse['body'] ?? loginResponse['rawBody'],
        );
        return ResponseHandler.error(
          obdxError.httpStatusCode ?? loginStatusCode,
          obdxError.userMessage,
          obdxError: obdxError,
        );
      }
      if (loginStatusCode != StatusCode.OK) {
        final obdxError = ObdxErrorMapper.fromHttpResponse(
          loginStatusCode,
          loginResponse['body'] ?? loginResponse['rawBody'],
        );
        return ResponseHandler.error(
          obdxError.httpStatusCode ?? loginStatusCode,
          obdxError.userMessage,
          obdxError: obdxError,
        );
      }

      final loginBodyMap = loginResponse['body'];
      if (loginBodyMap is! Map<String, dynamic>) {
        return ResponseHandler.error(
          loginStatusCode,
          'Login response is missing token payload.',
        );
      }

      final token = TokenResponse.fromJson(loginBodyMap);
      if (token.accessToken.isEmpty) {
        return ResponseHandler.error(
          loginStatusCode,
          'Login response is missing access token.',
        );
      }

      final partialTrace = LoginTrace(
        publicKeyResponse: publicKeyResult.data!,
        saltResponse: saltResult.data!,
        encryptedPassword: encryptedPassword,
        loginResponse: loginResponse,
        displayName: JwtUtils.extractName(token.accessToken),
        debug: kDebugMode
            ? {
                'saltUsed': salt,
              }
            : null,
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
              userName: loginBody.userName,
              partialTrace: partialTrace,
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

      final completed = await _completeLoginTrace(
        partialTrace,
        profileResponse: profileResponse,
      );
      if (completed is! Success<LoginTrace>) {
        return _mapFailure(completed);
      }
      RegistrationSessionHolder.instance.clear();
      return ResponseHandler.success(
        LoginFlowResult.complete(completed.data!),
      );
    } catch (e) {
      if (kIsWeb && _enableWebTempAuthBypass) {
        return ResponseHandler.success(
          LoginFlowResult.complete(
            LoginTrace(
              publicKeyResponse: const {'status': 'skipped_web_temp_bypass'},
              saltResponse: const {'status': 'skipped_web_temp_bypass'},
              encryptedPassword: 'WEB_TEMP_BYPASS',
              loginResponse: {
                'statusCode': StatusCode.OK,
                'headers': <String, String>{},
                'rawBody':
                    '{"token":"WEB_TEMP_BYPASS_TOKEN","tempBypass":true}',
                'body': {
                  'token': 'WEB_TEMP_BYPASS_TOKEN',
                  'tempBypass': true,
                },
              },
              debug: {
                'tempBypass': true,
                'tempBypassReason': e.toString(),
                'userName': loginBody.userName,
              },
            ),
          ),
        );
      }
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<LoginTrace>> _completeLoginTrace(
    LoginTrace partial, {
    required Map<String, dynamic> profileResponse,
  }) async {
    String? displayName = partial.displayName;
    final profileBody = profileResponse['body'];
    if (profileBody is Map<String, dynamic>) {
      final userProfile = profileBody['userProfile'] as Map<String, dynamic>?;
      final first = (userProfile?['firstName'] ?? '').toString().trim();
      final last = (userProfile?['lastName'] ?? '').toString().trim();
      final full = '$first $last'.trim();
      if (full.isNotEmpty) displayName = full;
    }

    final cookieModel = await PreferenceHelper.getInstance().getCookieModel();
    return ResponseHandler.success(
      LoginTrace(
        publicKeyResponse: partial.publicKeyResponse,
        saltResponse: partial.saltResponse,
        encryptedPassword: partial.encryptedPassword,
        loginResponse: partial.loginResponse,
        profileResponse: profileResponse,
        displayName: displayName,
        debug: kDebugMode
            ? {
                ...?partial.debug,
                'sessionCookies': [
                  if (cookieModel.secretKey != null) 'secretKey',
                  if (cookieModel.jsessionId != null) 'JSESSIONID',
                ],
              }
            : null,
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
