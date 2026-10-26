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
  static const _mailCategories = '/digx-common/collaboration/v1/mailCategories';

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

  // ── Compose / Reply (Phase 2, mailbox.md §6) ──

  /// `GET mailCategories` → `mailCategoryDTOs[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchMailCategories() => _get(_mailCategories, const {});

  /// `GET user me/party` (OBDX passes `media` unset, so nothing).
  Future<ResponseHandler<Map<String, dynamic>>> fetchParty() => _get(ApiConst.partyMeApi, const {});

  /// `GET user me/party/relations` → `partyToPartyRelationship[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchPartyRelations() => _get('${ApiConst.partyMeApi}/relations', const {});

  /// `POST mailbox/mails` (compose-mail/hooks.js:242).
  Future<ResponseHandler<Map<String, dynamic>>> sendMail(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _write('POST', '$_mailbox/mails', body, challengeResponseHeader);

  /// `POST mailbox/mails/{id}/replyMail` (message-detail/hooks.js:517).
  Future<ResponseHandler<Map<String, dynamic>>> replyMail(String id, Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _write('POST', '$_mailbox/mails/${Uri.encodeComponent(id)}/replyMail', body, challengeResponseHeader);

  /// `POST content contents`, multipart `file`, `transactionType=IM`,
  /// `isShared=true`. From Compose, OBDX also sends `?fileName=<index in
  /// the batch>` and the header `X-CHALLENGE_RESPONSE: true`
  /// (compose-mail/hooks.js:363-388); Reply sends neither
  /// (message-detail/hooks.js:390-404).
  Future<ResponseHandler<Map<String, dynamic>>> uploadContent({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    int? composeIndex,
    String? challengeResponseHeader,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(_contents),
        queryParameters: {if (composeIndex != null) 'fileName': '$composeIndex'},
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: fileName, contentType: DioMediaType.parse(mimeType)),
          'transactionType': 'IM',
          'isShared': 'true',
        }),
        options: Options(
          contentType: 'multipart/form-data',
          headers: {
            if (challengeResponseHeader != null && challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader
            else if (composeIndex != null)
              ApiConst.xChallengeResponse: 'true',
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

  /// `DELETE content contents/{id}?transactionType=IM`: an attachment taken
  /// off before sending (compose-mail/hooks.js:259).
  Future<ResponseHandler<Map<String, dynamic>>> deleteContent(String contentId, {String? challengeResponseHeader}) =>
      _write('DELETE', '$_contents/${Uri.encodeComponent(contentId)}?transactionType=IM', null, challengeResponseHeader);

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

  Future<ResponseHandler<Map<String, dynamic>>> _put(String path, Map<String, dynamic> body, String? challengeResponseHeader) =>
      _write('PUT', path, body, challengeResponseHeader);

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
