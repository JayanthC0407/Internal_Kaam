import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:ubci_bank/src/core/config/app_locale_holder.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';

class ObdxApiUtils {
  ObdxApiUtils._();

  /// Appends `locale` query param using [AppLocaleHolder] unless [locale] is set.
  ///
  /// Maps short app language codes to OBDX region tags via
  /// [LocaleConfig.obdxLocaleQueryParam] (e.g. `en` → `en-US`).
  static String appendLocaleQuery(String path, {String? locale}) {
    final languageCode = locale ?? AppLocaleHolder.instance.languageCode;
    final code = LocaleConfig.obdxLocaleQueryParam(languageCode);
    final separator = path.contains('?') ? '&' : '?';
    return '$path${separator}locale=$code';
  }

  static Map<String, dynamic> asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return {};
  }

  static Map<String, dynamic> wrapHttpResponse(Response<dynamic> response) {
    return {
      'statusCode': response.statusCode,
      'headers': response.headers.map,
      'rawBody': response.data is String
          ? response.data
          : jsonEncode(response.data),
      'body': asMap(response.data),
    };
  }

  /// Case-insensitive lookup into the `headers` map produced by
  /// [wrapHttpResponse] (dio's `Headers.map` is `Map<String, List<String>>`).
  /// Used to read OBDX's `X-CHALLENGE` step-up-auth header.
  static String? headerValue(dynamic headers, String name) {
    if (headers is! Map) return null;
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toString().toLowerCase() != target) continue;
      final value = entry.value;
      if (value is List && value.isNotEmpty) return value.first?.toString();
      if (value != null) return value.toString();
    }
    return null;
  }

  /// OBDX often returns HTTP 200/417 with `result: SUCCESSFUL` and
  /// `message.type: ERROR` for business failures (wrong OTP, validation, etc.).
  static bool hasErrorMessage(Map<String, dynamic> body) {
    bool isError(dynamic message) {
      if (message is! Map) return false;
      return message['type']?.toString().toUpperCase() == 'ERROR';
    }

    if (isError(body['message'])) return true;
    final status = body['status'];
    if (status is Map && isError(status['message'])) return true;
    return false;
  }

  /// True when the payload indicates business success (not an ERROR message).
  static bool isSuccessfulPayload(Map<String, dynamic> body) {
    if (hasErrorMessage(body)) return false;

    final status = body['status'];
    if (status is Map) {
      final result = status['result']?.toString().toUpperCase();
      if (result == 'SUCCESSFUL' || result == 'SUCCESS') return true;
      if (result != null && result.isNotEmpty) return false;
    }

    final topResult = body['result']?.toString().toUpperCase();
    return topResult == 'SUCCESSFUL' || topResult == 'SUCCESS';
  }

  /// Digx-ui forgot username/password OTP *completion* after challenge response:
  /// - `{"tokenValid":false}` (forgot password), or
  /// - `status.result: SUCCESSFUL` without a fresh OTP challenge.
  ///
  /// Do **not** use this for the initial SMS kickoff body that includes
  /// `status.referenceNumber` + INFO — that must open the OTP screen.
  static bool isForgotCredentialsCompleted(Map<String, dynamic> body) {
    if (hasErrorMessage(body)) return false;
    if (body.containsKey('tokenValid')) return true;

    // SUCCESSFUL + status.referenceNumber + INFO/apiType sms = OTP sent, not done.
    if (smsOtpChallengeReference(body) != null) return false;

    return isSuccessfulPayload(body);
  }

  /// SMS / credentials kickoff: `status.referenceNumber` (HTTP 200 INFO).
  static String? smsOtpChallengeReference(Map<String, dynamic> body) {
    final status = body['status'];
    if (status is! Map) return null;
    final reference =
        (status['referenceNumber'] ?? status['referenceNo'])?.toString().trim();
    if (reference == null || reference.isEmpty) return null;

    final message = status['message'];
    final messageType = message is Map
        ? message['type']?.toString().toUpperCase()
        : null;
    // Treat INFO (or missing type) + reference as an OTP challenge kickoff.
    if (messageType == 'ERROR') return null;
    return reference;
  }
}
