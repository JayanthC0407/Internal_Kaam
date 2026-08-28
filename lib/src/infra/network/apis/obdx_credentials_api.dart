import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Forgot username / password APIs (anonymous JWT via [RegistrationSessionHolder]).
class ObdxCredentialsApi extends ObdxApiBase {
  ObdxCredentialsApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  static bool _challengeValidateStatus(int? status) {
    return status != null &&
        (status == StatusCode.OK || status == ApiConst.expectationFailed);
  }

  Future<ResponseHandler<Map<String, dynamic>>> forgotUserId({
    required String emailId,
    required String dateOfBirth,
    String? challengeResponseHeader,
  }) {
    return _postCredentials(
      path: ApiConst.forgotUserIdApi,
      body: {
        'emailId': emailId,
        'dateOfBirth': dateOfBirth,
      },
      challengeResponseHeader: challengeResponseHeader,
    );
  }

  Future<ResponseHandler<Map<String, dynamic>>> forgotCredentials({
    required String userId,
    required String dateOfBirth,
    String? challengeResponseHeader,
  }) {
    return _postCredentials(
      path: ApiConst.forgotCredentialsApi,
      body: {
        'userId': userId,
        'dateOfBirth': dateOfBirth,
      },
      challengeResponseHeader: challengeResponseHeader,
    );
  }

  Future<ResponseHandler<Map<String, dynamic>>> _postCredentials({
    required String path,
    required Map<String, dynamic> body,
    String? challengeResponseHeader,
  }) async {
    try {
      final headers = <String, dynamic>{
        ApiConst.contentTypeKey: ApiConst.contentTypeValue,
      };
      if (challengeResponseHeader != null &&
          challengeResponseHeader.isNotEmpty) {
        headers[ApiConst.xChallengeResponse] = challengeResponseHeader;
      }

      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(path),
        data: jsonEncode(body),
        options: Options(
          headers: headers,
          validateStatus: _challengeValidateStatus,
        ),
      );

      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }
}
