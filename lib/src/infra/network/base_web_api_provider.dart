import 'package:dio/dio.dart';
import 'package:ubci_bank/src/core/constants/adlog.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

abstract class BaseWebApiProvider {
  Future<ResponseHandler<T>> getErrorResponse<T>(DioException error) async {
    final obdxError = ObdxErrorMapper.fromDioException(error);
    if (obdxError.isNetworkIssue) {
      return ResponseHandler.networkError(obdxError: obdxError);
    }

    return ResponseHandler.error(
      obdxError.httpStatusCode,
      obdxError.userMessage,
      requestId: obdxError.requestId,
      obdxError: obdxError,
    );
  }

  Future<ResponseHandler<T>> getExceptionErrorResponse<T>(
    Object exception,
    StackTrace stack,
  ) async {
    adLogError(exception, stack);
    return ResponseHandler.exceptionError();
  }

  ResponseHandler<T> errorFromHttpResponse<T>(
    int? statusCode,
    dynamic body, {
    String? requestId,
  }) {
    final obdxError =
        ObdxErrorMapper.fromHttpResponse(statusCode, body, requestId: requestId);
    if (obdxError.isNetworkIssue) {
      return ResponseHandler.networkError(obdxError: obdxError);
    }

    return ResponseHandler.error(
      obdxError.httpStatusCode ?? statusCode,
      obdxError.userMessage,
      requestId: obdxError.requestId ?? requestId,
      obdxError: obdxError,
    );
  }
}
