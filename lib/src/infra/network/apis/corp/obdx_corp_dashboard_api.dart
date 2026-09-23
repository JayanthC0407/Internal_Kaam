import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Personalized-dashboard APIs: the user's saved configuration, the
/// authorization set it is filtered against, and the widget catalog.
class ObdxCorpDashboardApi extends ObdxApiBase {
  ObdxCorpDashboardApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  /// `GET /digx-admin/config/v1/dashboards/modules?class=…&value=…`
  ///
  /// [dashboardClass] / [dashboardClassValue] come from the user's `me`
  /// response — never hard-coded, since a user without a personalized
  /// dashboard resolves to a different class than the captured
  /// `CUSTOM`/`custom` pair.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDashboardConfig({
    required String dashboardClass,
    required String dashboardClassValue,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(CorpApiConst.dashboardModulesApi),
        queryParameters: {
          'class': dashboardClass,
          'value': dashboardClassValue,
        },
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

  /// `PUT /digx-admin/config/v1/dashboards/user/{dashboardId}`
  ///
  /// [payload] must be a complete configuration — the host replaces the
  /// whole layout object rather than merging, so every breakpoint has to be
  /// present. `CorpDashboardConfig.toUpdatePayload()` guarantees that.
  Future<ResponseHandler<Map<String, dynamic>>> saveDashboardConfig({
    required String dashboardId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await dio.put(
        ObdxApiUtils.appendLocaleQuery(
          CorpApiConst.dashboardUserApi(dashboardId),
        ),
        data: payload,
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

  /// `GET /digx-common/user/v1/me/components`
  Future<ResponseHandler<Map<String, dynamic>>> fetchAuthorizedComponents() async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(CorpApiConst.meComponentsApi),
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

  /// `GET /framework/json/moduleComponents.json` — the environment's own
  /// widget catalog.
  ///
  /// Static JSON rather than a digx API, so it carries no `locale` query
  /// and no `status` envelope. A cache-buster matches how the web client
  /// fetches the sibling menu JSON.
  Future<ResponseHandler<Map<String, dynamic>>> fetchModuleComponents() async {
    try {
      final response = await dio.get(
        CorpApiConst.moduleComponentsPath,
        queryParameters: {
          'bust': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          headers: {'Accept': 'application/json, text/plain, */*'},
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
