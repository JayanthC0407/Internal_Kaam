import 'package:dio/dio.dart';

/// No-op SSL pinning on platforms without `dart:io` (web).
class DioSslPinning {
  DioSslPinning._();

  static void apply(Dio dio) {}
}
