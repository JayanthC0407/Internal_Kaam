import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

class ObdxMobileApi extends ObdxApiBase {
  ObdxMobileApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  Future<ResponseHandler<Map<String, dynamic>>> registerMobileClient({
    required String osVersion,
    required String os,
    required String manufacturer,
    required String model,
    required String secureDeviceId,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.mobileClientApi),
        data: jsonEncode({
          'osVersion': osVersion,
          'os': os,
          'manufacturer': manufacturer,
          'model': model,
          'secureDeviceId': secureDeviceId,
        }),
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
}
