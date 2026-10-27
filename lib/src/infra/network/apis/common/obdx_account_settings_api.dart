import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Account Settings → Session Summary, Alerts Subscription, Change
/// Password. OBDX `apiType`s: `user` → `/digx-common/user/v1`, `sms` →
/// `/digx-admin/sms/v1`, `party` → `/digx-common/party/v1`, `alerts` →
/// [_alerts].
class ObdxAccountSettingsApi extends ObdxApiBase {
  ObdxAccountSettingsApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  /// `apiType: alerts`. Not in the channel bundle (the server maps it);
  /// alerts are admin-maintained like `sms` and `finlimit`, so it follows
  /// those — change it here if the bank's server differs.
  static const _alerts = '/digx-admin/alerts/v1';
  static const _sessions = '${ApiConst.profileApi}/sessions';

  // ── Session Summary ──

  /// `GET user me/sessions` → `userSessionDTOList[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchSessions() => _get(_sessions);

  /// `GET user me/sessions/search` with the session in a `SESSION-ID`
  /// header → `auditList[]` (OBDX adds a random `date` to beat caches).
  Future<ResponseHandler<Map<String, dynamic>>> fetchSessionActivity(String sessionId) => _get(
        '$_sessions/search',
        query: {'date': DateTime.now().microsecondsSinceEpoch.toString()},
        headers: {'SESSION-ID': sessionId},
      );

  // ── Change Password ──

  /// `GET sms users/myPasswordPolicy` → `passwordPolicyDTO[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchPasswordPolicy() => _get('/digx-admin/sms/v1/users/myPasswordPolicy');

  /// `PUT user me/credentials {oldPassword, changedPassword}`, both
  /// RSA-encrypted.
  Future<ResponseHandler<Map<String, dynamic>>> changePassword(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _write('PUT', '${ApiConst.profileApi}/credentials', body, challengeResponseHeader);

  // ── Alerts Subscription ──

  /// `GET user me` → `userProfile` (party, user id, contacts).
  Future<ResponseHandler<Map<String, dynamic>>> fetchMe() => _get(ApiConst.profileApi);

  /// `activityEventActions/modules` → `modules[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchModules() => _get('$_alerts/activityEventActions/modules');

  /// Subscribable alerts: `activityEventActions?alertType=S`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchEvents() =>
      _get('$_alerts/activityEventActions', query: const {'alertType': 'S'});

  /// The user's subscriptions; retail sends `party`, corporate `userId`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchSubscriptions(Map<String, dynamic> query) =>
      _get('$_alerts/actionSubscriptions', query: query);

  Future<ResponseHandler<Map<String, dynamic>>> createSubscription(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _write('POST', '$_alerts/actionSubscriptions', body, challengeResponseHeader);

  Future<ResponseHandler<Map<String, dynamic>>> updateSubscription(String id, Map<String, dynamic> body,
          {String? challengeResponseHeader}) =>
      _write('PUT', '$_alerts/actionSubscriptions/${Uri.encodeComponent(id)}', body, challengeResponseHeader);

  /// Unsubscribing from everything at a level deletes its record.
  Future<ResponseHandler<Map<String, dynamic>>> deleteSubscription(String id, {String? challengeResponseHeader}) =>
      _write('DELETE', '$_alerts/actionSubscriptions/${Uri.encodeComponent(id)}', null, challengeResponseHeader);

  /// `GET party parties/{id}/accounts?accountType=&taskCode=AL_N_CS`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchPartyAccounts(String partyId, String accountType) => _get(
        '/digx-common/party/v1/parties/${Uri.encodeComponent(partyId)}/accounts',
        query: {'accountType': accountType, 'taskCode': 'AL_N_CS'},
      );

  Future<ResponseHandler<Map<String, dynamic>>> _get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: query,
        options: Options(headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue, ...?headers}),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// A write: 202 (approval) and 417 (OTP) come back as data, not errors.
  Future<ResponseHandler<Map<String, dynamic>>> _write(
    String method,
    String path,
    Map<String, dynamic>? body,
    String? challengeResponseHeader,
  ) async {
    try {
      final response = await dio.request(
        ObdxApiUtils.appendLocaleQuery(path),
        data: body,
        options: Options(
          method: method,
          headers: {
            ApiConst.contentTypeKey: ApiConst.contentTypeValue,
            if (challengeResponseHeader != null && challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: (status) => status == 200 || status == 201 || status == 202 || status == 204 || status == 417,
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
