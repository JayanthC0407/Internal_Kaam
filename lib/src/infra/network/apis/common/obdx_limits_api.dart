import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX My Limits (`limits-enquiry/my-limit`): `sms`, `security` and
/// `finlimit`, all under `/digx-admin`. Query parameters are the ones the
/// retail path sends (docs/obdx/features/my-limits.md §3).
class ObdxLimitsApi extends ObdxApiBase {
  ObdxLimitsApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  /// Channels: `accessPointListDTO[]` (hooks.js:291).
  Future<ResponseHandler<Map<String, dynamic>>> fetchChannels() =>
      _get(ApiConst.accessPointsApi, const {'accessType': 'INT', 'accessPointStatus': 'Y'});

  /// `isEffectiveSameDay` (hooks.js:1136).
  Future<ResponseHandler<Map<String, dynamic>>> fetchEffectiveToday() =>
      _get(ApiConst.limitPackagesEffectiveTodayApi, const {});

  /// Transactions: `taskList[]` (hooks.js:595).
  Future<ResponseHandler<Map<String, dynamic>>> fetchLimitTransactions() =>
      _get(ApiConst.limitResourceTasksApi, const {'aspects': 'limit', 'view': 'list'});

  /// Task groups and their transactions: `taskGroupDTOlist[]` (hooks.js:429).
  Future<ResponseHandler<Map<String, dynamic>>> fetchTaskGroups() =>
      _get(ApiConst.limitTaskGroupsApi, const {'taskAspect': 'limits'});

  /// The bank's limits for [channelId] (hooks.js:430).
  Future<ResponseHandler<Map<String, dynamic>>> fetchMyAssignedLimits(String channelId) =>
      _get(ApiConst.myAssignedLimitsApi, _channel(channelId));

  /// The user's own (custom) limits for [channelId] (hooks.js:433).
  Future<ResponseHandler<Map<String, dynamic>>> fetchMyCustomLimits(String channelId) =>
      _get(ApiConst.myCustomLimitsApi, _channel(channelId));

  /// Used so far: [period] is `DAILY` or `MONTHLY` (`limitType=PER#…`,
  /// `entityType=PARTY` for retail, hooks.js:271, 431-432).
  Future<ResponseHandler<Map<String, dynamic>>> fetchUtilization(String channelId, String period) =>
      _get(ApiConst.financialLimitUtilizationApi, {
        'limitType': 'PER#$period',
        'entityType': 'PARTY',
        'accessPointGroupType': 'SINGLE',
        'accessPointValue': channelId,
      });

  static Map<String, dynamic> _channel(String channelId) =>
      {'accessPointValue': channelId, 'accessPointGroupType': 'SINGLE'};

  Future<ResponseHandler<Map<String, dynamic>>> _get(String path, Map<String, dynamic> query) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: query,
        options: Options(headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue}),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }
}
