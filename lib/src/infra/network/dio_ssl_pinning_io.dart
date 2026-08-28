import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:ubci_bank/src/core/config/ssl_pin_config.dart';
import 'package:ubci_bank/src/infra/network/ssl_pin_validator.dart';

/// Configures Dio [IOHttpClientAdapter] certificate pinning on mobile/desktop IO.
class DioSslPinning {
  DioSslPinning._();

  static void apply(Dio dio) {
    if (!SslPinConfig.shouldEnforcePinning) {
      return;
    }

    dio.httpClientAdapter = IOHttpClientAdapter(
      validateCertificate: SslPinValidator.validate,
    );
  }
}
