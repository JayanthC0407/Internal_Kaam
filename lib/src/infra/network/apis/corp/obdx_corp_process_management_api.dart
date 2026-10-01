import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Process-management records — the corporate lending applications behind
/// the `loan-application-tracker` widget (widgets capture).
class ObdxCorpProcessManagementApi extends ObdxApiBase {
  ObdxCorpProcessManagementApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  /// `GET /digx-processmanagement/v1/processManagement?moduleId=…&partyId=…`
  Future<ResponseHandler<Map<String, dynamic>>> fetchProcesses({
    required String partyId,
    String moduleId = CorpApiConst.loanProcessModuleId,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(CorpApiConst.processManagementApi),
        queryParameters: {'moduleId': moduleId, 'partyId': partyId},
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
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
