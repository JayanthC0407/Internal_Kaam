import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Shared response handling for repositories that talk to OBDX.
///
/// Treats OBDX's two failure shapes identically: a non-200 HTTP status, and
/// a 200 whose body carries `status.message.type: ERROR` (which OBDX uses
/// for business failures).
///
/// Lives in `common/` so user-type-agnostic repositories — the personalized
/// dashboard's, for one — can use it without depending on the Corporate
/// tree. `CorpRepositoryBase` extends this rather than duplicating it.
abstract class ObdxRepositoryBase {
  /// Unwraps the `{ statusCode, headers, body }` envelope from
  /// `ObdxApiUtils.wrapHttpResponse` and runs [parse] on the body, mapping
  /// every failure mode onto [ResponseHandler].
  Future<ResponseHandler<T>> parseBody<T>(
    ResponseHandler<Map<String, dynamic>> result,
    T Function(Map<String, dynamic> body) parse,
  ) async {
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return mapFailure(result);
    }

    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);

    if (statusCode != StatusCode.OK) {
      final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    if (ObdxApiUtils.hasErrorMessage(body)) {
      final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    try {
      return ResponseHandler.success(parse(body), code: statusCode);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Re-types a failed [ResponseHandler] without losing its mapped
  /// [ObdxError], so the UI can still localize the message.
  ResponseHandler<T> mapFailure<T>(ResponseHandler<dynamic> result) {
    if (result is Error) {
      return ResponseHandler.error(
        result.code,
        result.error,
        requestId: result.requestId,
        obdxError: result.obdxError,
      );
    }
    if (result is NetworkError) {
      return ResponseHandler.networkError(obdxError: result.obdxError);
    }
    return ResponseHandler.exceptionError();
  }
}
