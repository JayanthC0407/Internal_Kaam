import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Account Settings → Preferences. Each call names the OBDX component it
/// comes from; OBDX `apiType`s map to these context roots:
/// `user` → `/digx-common/user/v1`, `sms` → `/digx-admin/sms/v1`,
/// `access` → `/digx-admin/access/v1`, `security` → `/digx-admin/security/v1`,
/// `mobile` → `/digx-infra/mobile/v1`, `content` → `/digx-common/content/v1`.
class ObdxPreferencesApi extends ObdxApiBase {
  ObdxPreferencesApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  static const _sms = '/digx-admin/sms/v1';
  static const _access = '/digx-admin/access/v1';
  static const _mobile = '/digx-infra/mobile/v1';
  static const _contents = '/digx-common/content/v1/contents';

  static const userPreferencesApi = '$_sms/userPreferences';

  // ── Profile (base-components-profile) ──

  /// `GET user me/party`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchParty() => _get(ApiConst.partyMeApi);

  /// `GET user profileConfig` → `userProfileConfigDTO`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchProfileConfig() => _get(ApiConst.profileConfigApi);

  /// `GET origination enumerations/country`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCountries() => _get(ApiConst.countryEnumerationApi);

  /// `PUT user me/party` with `{attr_name, attr_value}`.
  Future<ResponseHandler<Map<String, dynamic>>> updateParty(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _write('PUT', ApiConst.partyMeApi, body, challengeResponseHeader);

  /// Download: `GET user me/party?media=text/csv&mediaFormat=csv`, raw bytes.
  Future<ResponseHandler<List<int>>> downloadPartyCsv() async {
    try {
      final response = await dio.get<List<int>>(
        ObdxApiUtils.appendLocaleQuery(ApiConst.partyMeApi),
        queryParameters: const {'media': 'text/csv', 'mediaFormat': 'csv'},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Accept': 'text/csv, application/octet-stream, */*'},
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return ResponseHandler.exceptionError();
      return ResponseHandler.success(List<int>.from(bytes), code: response.statusCode ?? 0);
    } on DioException catch (error) {
      return getErrorResponse<List<int>>(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse<List<int>>(exc, stack);
    }
  }

  // ── userPreferences (sms-primary-account, third-party-consents, generic-settings) ──

  Future<ResponseHandler<Map<String, dynamic>>> fetchUserPreferences() => _get(userPreferencesApi);

  Future<ResponseHandler<Map<String, dynamic>>> updateUserPreferences(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _write('PUT', userPreferencesApi, body, challengeResponseHeader);

  // ── Third Party Applications ──

  /// `GET sms accessPoints/{id}` → `accessPointDTO` (OBDX batches these).
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccessPoint(String id) =>
      _get('${ApiConst.accessPointsApi}/${Uri.encodeComponent(id)}');

  /// `GET content contents/{id}` → `contentDTOList[0]` (the app's logo).
  Future<ResponseHandler<Map<String, dynamic>>> fetchContent(String contentId) =>
      _get('$_contents/${Uri.encodeComponent(contentId)}');

  /// `GET access accountAccess/me/accessPointAccount/{accessPointId}`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchConsentSetup(String accessPointId) =>
      _get('$_access/accountAccess/me/accessPointAccount/${Uri.encodeComponent(accessPointId)}');

  /// `PUT access accountAccess/me/accessPointAccount`.
  Future<ResponseHandler<Map<String, dynamic>>> updateConsentSetup(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _write('PUT', '$_access/accountAccess/me/accessPointAccount', body, challengeResponseHeader);

  // ── Security & Login ──

  Future<ResponseHandler<Map<String, dynamic>>> fetchSecurityQuestions() => _get(ApiConst.securityQuestionsMasterApi);

  Future<ResponseHandler<Map<String, dynamic>>> fetchSecurityQuestionCount() => _get(ApiConst.userSecurityQuestionsCountApi);

  Future<ResponseHandler<Map<String, dynamic>>> fetchUserSecurityQuestions() => _get(ApiConst.userSecurityQuestionsApi);

  /// `POST` the first time (Set up now), `PUT` to change them (Edit).
  Future<ResponseHandler<Map<String, dynamic>>> saveUserSecurityQuestions(Map<String, dynamic> body,
          {required bool create, String? challengeResponseHeader}) =>
      _write(create ? 'POST' : 'PUT', ApiConst.userSecurityQuestionsApi, body, challengeResponseHeader);

  /// `POST sms softtokenseed/qr?authType=OMA&download=false`; "Other Mobile
  /// Authenticator" sends no `authType`.
  Future<ResponseHandler<Map<String, dynamic>>> generateSoftToken({String? authType, String? challengeResponseHeader}) => _write(
        'POST',
        '$_sms/softtokenseed/qr',
        const {'userid': null, 'roles': []},
        challengeResponseHeader,
        query: {if (authType != null) 'authType': authType, 'download': 'false'},
      );

  /// `GET mobile smsbanking/pinRegistration`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchSmsBanking() => _get('$_mobile/smsbanking/pinRegistration');

  /// `PUT mobile smsbanking/pinRegistration`: a toggle or `{pin}`.
  Future<ResponseHandler<Map<String, dynamic>>> updateSmsBanking(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _write('PUT', '$_mobile/smsbanking/pinRegistration', body, challengeResponseHeader);

  // ── Settings: devices and push ──

  Future<ResponseHandler<Map<String, dynamic>>> fetchRegisteredDevices() => _get('${ApiConst.mobileClientApi}/registeredDevices');

  /// `DELETE mobile mobileClient/os/{os}`.
  Future<ResponseHandler<Map<String, dynamic>>> unregisterDevices(String os, {String? challengeResponseHeader}) =>
      _write('DELETE', '${ApiConst.mobileClientApi}/os/${Uri.encodeComponent(os)}', null, challengeResponseHeader);

  Future<ResponseHandler<Map<String, dynamic>>> fetchPushTokens() => _get('${ApiConst.mobileClientApi}/registeredPushToken');

  /// `DELETE mobile mobileClient/pushToken/os/{os}`.
  Future<ResponseHandler<Map<String, dynamic>>> unregisterPush(String os, {String? challengeResponseHeader}) =>
      _write('DELETE', '${ApiConst.mobileClientApi}/pushToken/os/${Uri.encodeComponent(os)}', null, challengeResponseHeader);

  Future<ResponseHandler<Map<String, dynamic>>> _get(String path) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        options: Options(headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue}),
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
    String? challengeResponseHeader, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await dio.request(
        ObdxApiUtils.appendLocaleQuery(path),
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            ApiConst.contentTypeKey: ApiConst.contentTypeValue,
            if (challengeResponseHeader != null && challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: (status) => status == 200 || status == 201 || status == 202 || status == 417,
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
