import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';

/// Legacy wrapper — prefer [ObdxErrorMapper.fromDioException].
class AppDioException implements Exception {
  AppDioException.fromDioError(DioException dioError)
      : errorMessage = ObdxErrorMapper.fromDioException(dioError).userMessage;

  final String errorMessage;
}
