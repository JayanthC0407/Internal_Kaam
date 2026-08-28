import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/config/env_config.dart';
import 'package:ubci_bank/src/core/models/token_response.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/session/registration_session_holder.dart';

class ObdxAuthApi extends ObdxApiBase {
  ObdxAuthApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  Future<void> initSession() async {
    final paths = EnvConfig.sessionInitPaths;
    for (final path in paths) {
      try {
        // Keep a leading `/` so Dio joins as `{baseUrl}/digx-ui` (not `host:portDIGX`).
        final requestPath = path.startsWith('/') ? path : '/$path';
        await dio.get(
          requestPath,
          options: Options(
            headers: {
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
            responseType: ResponseType.plain,
          ),
        );
        return;
      } catch (_) {
        // try next path
      }
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> getAnonymousToken() async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.anonymousTokenApi),
        data: '',
        options: Options(
          headers: {ApiConst.contentTypeKey: 'application/json'},
        ),
      );

      if (response.statusCode != StatusCode.OK) {
        return errorFromHttpResponse(response.statusCode, response.data);
      }

      final body = ObdxApiUtils.asMap(response.data);
      final token = TokenResponse.fromJson(body);
      if (token.accessToken.isEmpty) {
        return ResponseHandler.error(
          response.statusCode,
          'Anonymous token response is missing token.',
        );
      }

      // Registration-only token — do not persist as a logged-in session.
      RegistrationSessionHolder.instance.setAnonymous(token);
      return ResponseHandler.success(body, code: response.statusCode ?? 0);
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> getPublicKey() async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.publicKeyApi),
        options: Options(headers: {ApiConst.contentTypeKey: 'application/json'}),
      );
      final payload = ObdxApiUtils.asMap(response.data);
      if (_hasUsablePublicKey(payload)) {
        return ResponseHandler.success(payload, code: response.statusCode ?? 0);
      }

      if (kIsWeb) {
        await initSession();
        final retry = await dio.get(
          ObdxApiUtils.appendLocaleQuery(ApiConst.publicKeyApi),
          options:
              Options(headers: {ApiConst.contentTypeKey: 'application/json'}),
        );
        final retryPayload = ObdxApiUtils.asMap(retry.data);
        if (_hasUsablePublicKey(retryPayload)) {
          return ResponseHandler.success(
            retryPayload,
            code: retry.statusCode ?? 0,
          );
        }
      }

      return ResponseHandler.error(
        response.statusCode,
        'Public key payload is missing required fields.',
      );
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> getSalt(String userName) async {
    try {
      var response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.saltApi),
        data: '',
      );
      if (response.statusCode != StatusCode.OK) {
        response = await dio.post(
          ObdxApiUtils.appendLocaleQuery(ApiConst.saltApi),
          data: jsonEncode({'userName': userName}),
        );
      }

      if (response.statusCode != StatusCode.OK) {
        return errorFromHttpResponse(response.statusCode, response.data);
      }
      return ResponseHandler.success(ObdxApiUtils.asMap(response.data));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> login({
    required String userName,
    required String encryptedPassword,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.loginApi),
        data: jsonEncode({
          'userName': userName,
          'password': encryptedPassword,
        }),
        options: Options(
          headers: {ApiConst.xAuthenticationType: 'CRED'},
        ),
      );

      final body = ObdxApiUtils.asMap(response.data);
      if (response.statusCode == StatusCode.OK) {
        final token = TokenResponse.fromJson(body);
        if (token.accessToken.isNotEmpty) {
          await PreferenceHelper.getInstance().saveAuthorization(token);
        }
      }

      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> requestJwtSetupToken({
    required String userName,
    required String encryptedPassword,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.jwtSetupApi),
        data: jsonEncode({
          'accessPointId': ApiConst.accessPointId,
          'password': encryptedPassword,
          'subject': userName,
        }),
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final body = ObdxApiUtils.asMap(response.data);
      if (response.statusCode != StatusCode.OK) {
        return errorFromHttpResponse(response.statusCode, response.data);
      }
      final setupToken = extractBiometricSetupToken(body);
      if (setupToken.isEmpty) {
        return ResponseHandler.error(
          response.statusCode,
          'JWT setup response is missing jwtoken.',
        );
      }

      return ResponseHandler.success(body, code: response.statusCode ?? 0);
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> loginWithBiometricToken({
    required String setupToken,
    required String deviceId,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.loginApi),
        data: jsonEncode({
          'token': setupToken,
          'deviceID': deviceId,
        }),
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final body = ObdxApiUtils.asMap(response.data);
      if (response.statusCode == StatusCode.OK) {
        final token = TokenResponse.fromJson(body);
        if (token.accessToken.isNotEmpty) {
          await PreferenceHelper.getInstance().saveAuthorization(token);
        }
      }

      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// Server logout — digx-ui: `POST /digx-infra/login/v1/logout?locale=...`.
  /// Empty body; session JWT + cookies required. Expects HTTP 202.
  Future<ResponseHandler<Map<String, dynamic>>> logout() async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.logoutApi),
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
        ),
      );

      final code = response.statusCode ?? 0;
      if (code == StatusCode.ACCEPTED ||
          code == StatusCode.OK ||
          code == StatusCode.NO_CONTENT) {
        return ResponseHandler.success(
          ObdxApiUtils.wrapHttpResponse(response),
          code: code,
        );
      }
      return errorFromHttpResponse(response.statusCode, response.data);
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// Resend login OTP — digx-ui: `POST /digx-admin/security/v1/2fa/{referenceNo}/resend`.
  /// Empty body; session JWT + cookies required.
  Future<ResponseHandler<Map<String, dynamic>>> resendTwoFactorOtp({
    required String referenceNo,
  }) async {
    try {
      final trimmed = referenceNo.trim();
      if (trimmed.isEmpty) {
        return ResponseHandler.exceptionError();
      }

      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.twoFactorResendApi(trimmed)),
        data: '',
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
        ),
      );

      if (response.statusCode != StatusCode.OK) {
        return errorFromHttpResponse(response.statusCode, response.data);
      }

      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  static String extractBiometricSetupToken(Map<String, dynamic> body) {
    return (body['jwtoken'] ?? body['jwtToken'] ?? '').toString().trim();
  }

  bool _hasUsablePublicKey(Map<String, dynamic> response) {
    final dto = response['publicKeyDTO'];
    if (dto is! Map<String, dynamic>) return false;
    final publicKey = dto['publicKey']?.toString().trim() ?? '';
    final modulus = dto['modulus']?.toString().trim() ?? '';
    final exponent = dto['publicExponent']?.toString().trim() ?? '';
    return publicKey.isNotEmpty || (modulus.isNotEmpty && exponent.isNotEmpty);
  }

  String extractPublicKey(Map<String, dynamic> response) {
    final dto = response['publicKeyDTO'] as Map<String, dynamic>?;
    for (final key in ['publicKey', 'key', 'rsaKey', 'value']) {
      final v = dto?[key] ?? response[key];
      if (v != null) return v.toString();
    }
    throw Exception('Cannot find public key in response: $response');
  }

  String extractSalt(Map<String, dynamic> response) {
    final dto = response['saltDTO'] as Map<String, dynamic>?;
    for (final key in ['id', 'salt', 'saltKey', 'saltValue', 'value']) {
      final v = dto?[key] ?? response[key];
      if (v != null) return v.toString();
    }
    throw Exception('Cannot find salt in response: $response');
  }
}
