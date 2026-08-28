import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ubci_bank/src/core/config/ssl_pin_config.dart';

/// Validates server leaf certificates against configured pin fingerprints.
class SslPinValidator {
  SslPinValidator._();

  static bool validate(X509Certificate? certificate, String host, int port) {
    if (!SslPinConfig.shouldEnforcePinning) {
      return true;
    }

    if (certificate == null) {
      return false;
    }

    final expectedHost = SslPinConfig.pinnedHost;
    if (expectedHost.isNotEmpty &&
        host.toLowerCase() != expectedHost.toLowerCase()) {
      return false;
    }

    final fingerprint = _sha256Base64(certificate.der);
    return SslPinConfig.pinFingerprints.contains(fingerprint);
  }

  static String _sha256Base64(List<int> derBytes) {
    final digest = sha256.convert(derBytes);
    return base64.encode(digest.bytes);
  }
}
