import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX Mailbox: `apiType: collaboration` → `/digx-common/collaboration/v1`
/// and attachments on `content` → `/digx-common/content/v1`
/// (docs/obdx/features/mailbox.md). Common: corporate users have the same
/// mailbox.
class ObdxMailboxApi extends ObdxApiBase {
  ObdxMailboxApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  static const _mailbox = '/digx-common/collaboration/v1/mailbox';
  static const _contents = '/digx-common/content/v1/contents';

  /// `GET mailbox/count`, no params (§2).
  Future<ResponseHandler<Map<String, dynamic>>> fetchCount() => _get('$_mailbox/count', const {});

  /// `GET mailbox/mails` with a folder's query (§3).
  Future<ResponseHandler<Map<String, dynamic>>> fetchMails(Map<String, dynamic> query) => _get('$_mailbox/mails', query);

  /// `GET mailbox/alerts` (§7).
  Future<ResponseHandler<Map<String, dynamic>>> fetchAlerts() => _get('$_mailbox/alerts', const {});

  /// `GET mailbox/mailers` (§8).
  Future<ResponseHandler<Map<String, dynamic>>> fetchNotifications() => _get('$_mailbox/mailers', const {});

  /// `GET mailbox/mailers/{messageId}`: OBDX passes the message id into the
  /// `mapId` path slot (notification-list/hooks.js:345).
  Future<ResponseHandler<Map<String, dynamic>>> fetchNotification(String messageId) =>
      _get('$_mailbox/mailers/${Uri.encodeComponent(messageId)}', const {});

  /// `GET contents/{id}?transactionType=IM` → `contentDTOList[0]` (§4).
  Future<ResponseHandler<Map<String, dynamic>>> fetchContent(String contentId) =>
      _get('$_contents/${Uri.encodeComponent(contentId)}', const {'transactionType': 'IM'});

  /// `PUT mailbox/mails/{id}`: read, delete, restore (§4-5).
  Future<ResponseHandler<Map<String, dynamic>>> updateMail(String id, Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _put('$_mailbox/mails/${Uri.encodeComponent(id)}', body, challengeResponseHeader);

  /// `PUT mailbox/alerts/{id}` (§7).
  Future<ResponseHandler<Map<String, dynamic>>> updateAlert(String id, Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _put('$_mailbox/alerts/${Uri.encodeComponent(id)}', body, challengeResponseHeader);

  /// `PUT mailbox/mailers/{mapId}` (§8).
  Future<ResponseHandler<Map<String, dynamic>>> updateNotification(String mapId, Map<String, dynamic> body,
          {String? challengeResponseHeader}) =>
      _put('$_mailbox/mailers/${Uri.encodeComponent(mapId)}', body, challengeResponseHeader);

  /// The attachment file: `contents/{id}?alt=media&transactionType=IM`
  /// (message-detail/hooks.js:407-409). Raw bytes, like statements.
  Future<ResponseHandler<List<int>>> downloadContent(String contentId) async {
    try {
      final response = await dio.get<List<int>>(
        ObdxApiUtils.appendLocaleQuery('$_contents/${Uri.encodeComponent(contentId)}'),
        queryParameters: const {'alt': 'media', 'transactionType': 'IM'},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Accept': 'application/octet-stream, application/json, */*'},
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

  /// A write: 202 (approval) and 417 (OTP) come back as data, not errors.
  Future<ResponseHandler<Map<String, dynamic>>> _put(String path, Map<String, dynamic> body, String? challengeResponseHeader) async {
    try {
      final response = await dio.put(
        ObdxApiUtils.appendLocaleQuery(path),
        data: body,
        options: Options(
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
