import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX Service Requests (`apiType: sr`, attachments on `content`, the
/// PDAN / PDAD account lists on `dda`). Common: corporate users raise and
/// track requests the same way.
class ObdxServiceRequestsApi extends ObdxApiBase {
  ObdxServiceRequestsApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  /// `apiType: sr`. Not in the channel bundle (the server maps it), so it
  /// follows the other `digx-common` modules — change it here if the
  /// bank's server differs.
  static const _sr = '/digx-common/sr/v1';
  static const _requests = '$_sr/servicerequest';
  static const _contents = '/digx-common/content/v1/contents';

  /// Track filter: `servicerequest/products` → `productResponse[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchProducts() => _get('$_requests/products');

  /// `servicerequest/products/{product}/categories` → `categoryResponse[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCategories(String product) =>
      _get('$_requests/products/${Uri.encodeComponent(product)}/categories');

  /// `enumerations/{name}` (sr): `srStatus`, `srRequestType`, `gender`,
  /// `salutation`, `country`, `country/{code}/state`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchEnumeration(String name) => _get('$_sr/enumerations/$name');

  /// Track list: `GET servicerequest` with the filter's query → `list[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchRequests(Map<String, dynamic> query) => _get(_requests, query);

  /// One request: `GET servicerequest/{id}`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchRequest(String id) => _get('$_requests/${Uri.encodeComponent(id)}');

  /// Raise: every definition the user may raise → `serviceRequestResponse[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDefinitions() => _get('$_requests/definitions');

  /// One definition with its `form`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDefinition(String id) =>
      _get('$_requests/definitions/${Uri.encodeComponent(id)}');

  /// `POST servicerequest` (service-requests-verify).
  Future<ResponseHandler<Map<String, dynamic>>> submit(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _write('POST', _requests, body, challengeResponseHeader);

  /// PDAN / PDAD: `GET dda demandDeposit` → `accounts[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccounts() => _get(ApiConst.accountsApiDemandDeposit);

  /// PDAD: `demandDeposit/{account}/debitCards` → `debitCardDetails[]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDebitCards(String accountId) =>
      _get('${ApiConst.demandDepositAccountApi(accountId)}/debitCards');

  /// FFFU: `POST contents` (multipart `file`, `moduleIdentifier=SERVICE_REQUEST`).
  Future<ResponseHandler<Map<String, dynamic>>> uploadContent({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(_contents),
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: fileName, contentType: DioMediaType.parse(mimeType)),
          'moduleIdentifier': 'SERVICE_REQUEST',
        }),
        options: Options(
          contentType: 'multipart/form-data',
          validateStatus: (status) => status == 200 || status == 201 || status == 202,
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// FFFU delete icon: `DELETE contents/{id}`.
  Future<ResponseHandler<Map<String, dynamic>>> deleteContent(String contentId) =>
      _write('DELETE', '$_contents/${Uri.encodeComponent(contentId)}', null, null);

  /// An attachment's file: `contents/{id}?alt=media`.
  Future<ResponseHandler<List<int>>> downloadContent(String contentId) async {
    try {
      final response = await dio.get<List<int>>(
        ObdxApiUtils.appendLocaleQuery('$_contents/${Uri.encodeComponent(contentId)}'),
        queryParameters: const {'alt': 'media'},
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

  Future<ResponseHandler<Map<String, dynamic>>> _get(String path, [Map<String, dynamic>? query]) async {
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
