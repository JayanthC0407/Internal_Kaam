import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/dio_ssl_pinning.dart';
import 'package:ubci_bank/src/infra/network/dio_web_credentials.dart';
import 'package:ubci_bank/src/infra/network/interceptors/authorization_interceptor.dart';
import 'package:ubci_bank/src/infra/network/interceptors/logging_interceptor.dart';
import 'package:ubci_bank/src/infra/network/interceptors/obdx_cookie_interceptor.dart';
import 'package:ubci_bank/src/infra/network/interceptors/session_expiry_interceptor.dart';

/// Single shared Dio instance for all OBDX API modules.
class ObdxDioClient {
  ObdxDioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConst.resolvedBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        contentType: ApiConst.contentTypeValue,
        headers: {
          ApiConst.contentTypeKey: ApiConst.contentTypeValue,
        },
      ),
    );

    if (kIsWeb) {
      // Browser owns cookies — do not attach dio_cookie_manager (asserts on web).
      applyWebCredentials(_dio);
    } else {
      DioSslPinning.apply(_dio);
    }

    _dio.interceptors.addAll([
      if (!kIsWeb) CookieManager(ObdxCookieInterceptor()),
      AuthorizationInterceptor(),
      SessionExpiryInterceptor(),
      if (kDebugMode) LoggingInterceptor(),
    ]);
  }

  static final ObdxDioClient instance = ObdxDioClient._internal();

  late final Dio _dio;

  Dio get dio => _dio;
}
