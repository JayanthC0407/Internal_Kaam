import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/constants/adlog.dart';
import 'package:ubci_bank/src/core/models/account_type_option.dart';
import 'package:ubci_bank/src/core/models/registration_request.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

class ObdxRegistrationApi extends ObdxApiBase {
  ObdxRegistrationApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  Future<ResponseHandler<List<AccountTypeOption>>> fetchAccountTypes() async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.accountTypesApi),
        options: Options(headers: {ApiConst.contentTypeKey: 'application/json'}),
      );

      if (response.statusCode != StatusCode.OK) {
        return errorFromHttpResponse(response.statusCode, response.data);
      }

      final body = ObdxApiUtils.asMap(response.data);
      final options = AccountTypeOption.listFromPayload(body);
      return ResponseHandler.success(options, code: response.statusCode ?? 0);
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// Starts party/account lookup registration (sends verification code).
  Future<ResponseHandler<Map<String, dynamic>>> startRegistration({
    required RegistrationRequest request,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.registrationApi),
        data: jsonEncode(request.toJson()),
        options: Options(
          headers: {ApiConst.contentTypeKey: 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return ResponseHandler.success(
        ObdxApiUtils.wrapHttpResponse(response),
        code: response.statusCode ?? 0,
      );
    } on DioException catch (error) {
      final response = error.response;
      if (response != null) {
        return ResponseHandler.success(
          ObdxApiUtils.wrapHttpResponse(response),
          code: response.statusCode ?? 0,
        );
      }
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// Submits the verification code via `Token_id` header (no request body).
  ///
  /// Matches digx-ui: `PUT .../authentication?locale=en-US` with
  /// `Content-Length: 0` and header `Token_id: <otp>`.
  Future<ResponseHandler<Map<String, dynamic>>> authenticateRegistration({
    required String registrationId,
    required String verificationCode,
  }) async {
    try {
      final response = await dio.put(
        ObdxApiUtils.appendLocaleQuery(
          ApiConst.registrationAuthenticationApi(registrationId),
        ),
        // Do not send `data: ''` — empty string + JSON content-type triggers
        // OBDX DIGX_PROD_DEF_0000 on some hosts.
        options: Options(
          headers: {
            ApiConst.contentTypeKey: 'application/json',
            ApiConst.registrationTokenHeader: verificationCode.trim(),
          },
          contentType: Headers.jsonContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return ResponseHandler.success(
        ObdxApiUtils.wrapHttpResponse(response),
        code: response.statusCode ?? 0,
      );
    } on DioException catch (error) {
      final response = error.response;
      if (response != null) {
        return ResponseHandler.success(
          ObdxApiUtils.wrapHttpResponse(response),
          code: response.statusCode ?? 0,
        );
      }
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// Step 3 — creates the login username/password for a verified
  /// registration.
  ///
  /// Matches digx-ui: `POST .../registration/{id}/credentials` with a body of
  /// `{username, password, registrationId}` where `password` is the
  /// RSA-encrypted + URL-encoded value from [RsaCryptoUtils.encryptPassword]
  /// (see [ObdxPasswordCryptoService]).
  Future<ResponseHandler<Map<String, dynamic>>> submitCredentials({
    required String registrationId,
    required String username,
    required String encryptedPassword,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(
          ApiConst.registrationCredentialsApi(registrationId),
        ),
        data: jsonEncode({
          'username': username,
          'password': encryptedPassword,
          'registrationId': registrationId,
        }),
        options: Options(
          headers: {ApiConst.contentTypeKey: 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return ResponseHandler.success(
        ObdxApiUtils.wrapHttpResponse(response),
        code: response.statusCode ?? 0,
      );
    } on DioException catch (error) {
      final response = error.response;
      if (response != null) {
        return ResponseHandler.success(
          ObdxApiUtils.wrapHttpResponse(response),
          code: response.statusCode ?? 0,
        );
      }
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }
}
