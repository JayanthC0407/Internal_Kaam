import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX Login Flow Wizard (LFW) endpoints — authenticated session required.
///
/// Isolated from [ObdxAuthApi] / OTP so existing login flows stay unchanged.
class ObdxLoginWizardApi extends ObdxApiBase {
  ObdxLoginWizardApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  /// Accept non-5xx so repository can inspect 428 / DIGX body codes.
  static bool _modulesValidateStatus(int? status) {
    return status != null && status < 500;
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchDashboardModules() async {
    try {
      final path = ObdxApiUtils.appendLocaleQuery(
        '${ApiConst.dashboardModulesApi}?class=USER_TYPE&value=Customer',
      );
      final response = await dio.get(
        path,
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
          validateStatus: _modulesValidateStatus,
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchLoginFlow() {
    return _get(ApiConst.loginFlowApi);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchWizardSteps() {
    return _get('${ApiConst.wizardStepsApi}?wizardType=LFW');
  }

  Future<ResponseHandler<Map<String, dynamic>>> completeLoginFlowStep({
    required String stepId,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await dio.put(
        ObdxApiUtils.appendLocaleQuery(ApiConst.loginFlowStepApi(stepId)),
        data: body,
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

  Future<ResponseHandler<Map<String, dynamic>>> fetchSecurityQuestionCount() {
    return _get(ApiConst.userSecurityQuestionsCountApi);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchSecurityQuestions() {
    return _get(ApiConst.securityQuestionsMasterApi);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchUserSecurityQuestions() {
    return _get(ApiConst.userSecurityQuestionsApi);
  }

  /// Create the user's security question set — returns **201 Created**.
  Future<ResponseHandler<Map<String, dynamic>>> submitUserSecurityQuestions(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(ApiConst.userSecurityQuestionsApi),
        data: body,
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

  Future<ResponseHandler<Map<String, dynamic>>> fetchParty() {
    return _get(ApiConst.partyMeApi);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchProfileConfig() {
    return _get(ApiConst.profileConfigApi);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchCountries() {
    return _get(ApiConst.countryEnumerationApi);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchAccessPoints() {
    return _get(ApiConst.accessPointsApi);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchLimitPackageConfig() {
    return _get(ApiConst.limitPackagesEffectiveTodayApi);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchPartyLimits() {
    return _get(ApiConst.partyLimitsApi);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchLimitUtilization({
    required String period,
  }) {
    return _get(
      '${ApiConst.financialLimitUtilizationApi}?limitTypes=$period',
    );
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchCustomLimits() {
    return _get(ApiConst.myCustomLimitsApi);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchLimitTaskGroups() {
    return _get('${ApiConst.limitTaskGroupsApi}?taskAspect=limit');
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchLimitResourceTasks() {
    return _get(
      '${ApiConst.limitResourceTasksApi}?aspects=limit&view=list',
    );
  }

  Future<ResponseHandler<Map<String, dynamic>>> _get(String path) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
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
