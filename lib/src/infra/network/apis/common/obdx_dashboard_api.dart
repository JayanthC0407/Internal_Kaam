import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/dashboard_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Personalized-dashboard APIs: the user's saved configuration, the
/// authorization set it is filtered against, and the widget catalog.
class ObdxDashboardApi extends ObdxApiBase {
  ObdxDashboardApi([ObdxDioClient? client])
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
        ObdxApiUtils.appendLocaleQuery(DashboardApiConst.dashboardModulesApi),
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

  /// `POST /digx-admin/config/v1/dashboards/user` — creates the user's own
  /// `CUSTOM` dashboard. [payload] has the same three keys as the PUT
  /// (`dashboardName`, `dashboardDescription`, `layout`); the host answers
  /// 201 with the new `dashboardDTO` (`customize for new user.har` #26).
  Future<ResponseHandler<Map<String, dynamic>>> createDashboardConfig({
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(DashboardApiConst.dashboardsUserApi),
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

  /// `PUT /digx-admin/config/v1/dashboards/user/{dashboardId}`
  ///
  /// [payload] must be a complete configuration — the host replaces the
  /// whole layout object rather than merging, so every breakpoint has to be
  /// present. `DashboardConfig.toUpdatePayload()` guarantees that.
  Future<ResponseHandler<Map<String, dynamic>>> saveDashboardConfig({
    required String dashboardId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await dio.put(
        ObdxApiUtils.appendLocaleQuery(
          DashboardApiConst.dashboardUserApi(dashboardId),
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
  Future<ResponseHandler<Map<String, dynamic>>>
      fetchAuthorizedComponents() async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(DashboardApiConst.meComponentsApi),
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
  ///
  /// Read as plain text and decoded here, because a static file's
  /// `Content-Type` is whatever the web server in front of OBDX says, and
  /// a server that does not route `/framework/` to OBDX answers with some
  /// other page entirely — typically the app's own `index.html`, with a
  /// 200. The result's `body` is empty when the text is not a JSON object,
  /// and `contentType` / `bodyPreview` say what came back instead.
  Future<ResponseHandler<Map<String, dynamic>>> fetchModuleComponents() async {
    try {
      final response = await dio.get<String>(
        DashboardApiConst.moduleComponentsPath,
        queryParameters: {
          'bust': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'application/json, text/plain, */*'},
        ),
      );
      final text = response.data ?? '';
      Map<String, dynamic> body = const {};
      try {
        final decoded = jsonDecode(text.replaceFirst('﻿', ''));
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } on FormatException {
        // Not JSON — reported through `bodyPreview`.
      }
      return ResponseHandler.success({
        'statusCode': response.statusCode,
        'headers': response.headers.map,
        'contentType': response.headers.value('content-type'),
        'url': response.realUri.toString(),
        'bodyPreview': text.length > 80 ? text.substring(0, 80) : text,
        'body': body,
      });
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }
}
