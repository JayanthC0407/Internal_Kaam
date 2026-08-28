import 'package:ubci_bank/src/core/models/obdx_error.dart';

class ResponseHandler<T> {
  ResponseHandler._();

  factory ResponseHandler.initial() = Initial;

  factory ResponseHandler.loading(T? data) = Loading;

  factory ResponseHandler.success(T? data, {int code}) = Success;

  factory ResponseHandler.error(
    int? code,
    String? error, {
    String? requestId,
    bool showErrorToast,
    ObdxError? obdxError,
  }) = Error;

  factory ResponseHandler.networkError({ObdxError? obdxError}) =
      NetworkError;

  factory ResponseHandler.exceptionError() = ExceptionError;
}

class Initial<T> extends ResponseHandler<T> {
  Initial() : super._();
}

class Loading<T> extends ResponseHandler<T> {
  Loading(this.data) : super._();
  final T? data;
}

class Success<T> extends ResponseHandler<T> {
  Success(this.data, {this.code = 0}) : super._();
  final T? data;
  final int code;
}

class Error<T> extends ResponseHandler<T> {
  Error(
    this.code,
    this.error, {
    this.requestId,
    this.showErrorToast = false,
    this.obdxError,
  }) : super._();

  final int? code;
  final String? error;
  final String? requestId;
  final bool showErrorToast;
  final ObdxError? obdxError;
}

class NetworkError<T> extends ResponseHandler<T> {
  NetworkError({this.obdxError}) : super._();

  final ObdxError? obdxError;
}

class ExceptionError<T> extends ResponseHandler<T> {
  ExceptionError() : super._();
}
