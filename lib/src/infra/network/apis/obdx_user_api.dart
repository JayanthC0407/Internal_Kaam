import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/constants/adlog.dart';
import 'package:ubci_bank/src/core/models/obdx_challenge.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

class ObdxUserApi extends ObdxApiBase {
  ObdxUserApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  static bool _profileValidateStatus(int? status) {
    return status != null &&
        (status == StatusCode.OK || status == ApiConst.expectationFailed);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchProfile({
    String? challengeResponseHeader,
  }) async {
    try {
      final headers = <String, dynamic>{
        ApiConst.contentTypeKey: 'application/json',
      };
      if (challengeResponseHeader != null &&
          challengeResponseHeader.isNotEmpty) {
        headers[ApiConst.xChallengeResponse] = challengeResponseHeader;
      }

      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(ApiConst.profileApi),
        options: Options(
          headers: headers,
          validateStatus: _profileValidateStatus,
        ),
      );

      if (response.statusCode == StatusCode.UNAUTHORIZED && kDebugMode) {
        adLog('fetchProfile returned 401 — session may be invalid');
      }

      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// Submits login OTP via `GET /me` with `X-CHALLENGE_RESPONSE` (per client flow doc).
  Future<ResponseHandler<Map<String, dynamic>>> submitLoginOtp({
    required ObdxChallenge challenge,
    required String otp,
  }) {
    return fetchProfile(
      challengeResponseHeader: challenge.toChallengeResponseHeader(otp),
    );
  }
}
