import 'dart:convert';

/// Redacts sensitive values before debug logging.
class LogRedactor {
  LogRedactor._();

  static final RegExp _bearerToken =
      RegExp(r'Bearer\s+[A-Za-z0-9._\-+/=]+', caseSensitive: false);

  static final RegExp _jwt =
      RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+');

  static final RegExp _sensitiveJsonQuoted = RegExp(
    r'"(password|encryptedPassword|secretKey|accessToken|token|authorization|'
    r'debitCardNumber|debitCardPin|creditCardNumber|creditCardCVVNumber|'
    r'jwtoken|setupToken)"'
    r'\s*:\s*"[^"]*"',
    caseSensitive: false,
  );

  static final RegExp _sensitiveJsonField = RegExp(
    r'(password|encryptedPassword|secretKey|jsessionid|accessToken|token|'
    r'authorization|debitCardNumber|debitCardPin|creditCardNumber|'
    r'creditCardCVVNumber|jwtoken|setupToken)'
    r'(\s*[:=]\s*)([^",\s}\]]+)',
    caseSensitive: false,
  );

  static final RegExp _cookiePair = RegExp(
    r'(secretKey|JSESSIONID)=([^;\s,]+)',
    caseSensitive: false,
  );

  static const _sensitiveHeaderKeys = {
    'authorization',
    'cookie',
    'set-cookie',
    'token',
    'token_id',
    'x-challenge',
    'x-challenge_response',
    'x-challenge-response',
  };

  static String redact(String input) {
    if (input.isEmpty) return input;

    var result = input;
    result = result.replaceAll(_bearerToken, 'Bearer [REDACTED]');
    result = result.replaceAll(_jwt, '[JWT_REDACTED]');
    result = result.replaceAllMapped(
      _sensitiveJsonQuoted,
      (match) => '"${match.group(1)}":"[REDACTED]"',
    );
    result = result.replaceAllMapped(
      _sensitiveJsonField,
      (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
    );
    result = result.replaceAllMapped(
      _cookiePair,
      (match) => '${match.group(1)}=[REDACTED]',
    );
    return result;
  }

  /// Stringify request/response payloads with sensitive fields redacted.
  static String redactPayload(dynamic data) {
    if (data == null) return '(empty)';
    try {
      if (data is List<int>) {
        return '[bytes:${data.length}]';
      }
      final typeName = data.runtimeType.toString();
      if (typeName.contains('FormData')) {
        return '[FormData]';
      }
      if (data is String) {
        return redact(data);
      }
      return redact(const JsonEncoder.withIndent('  ').convert(data));
    } catch (_) {
      return redact(data.toString());
    }
  }

  static Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) {
    final redacted = <String, dynamic>{};
    headers.forEach((key, value) {
      final lower = key.toLowerCase();
      if (_sensitiveHeaderKeys.contains(lower)) {
        redacted[key] = '[REDACTED]';
      } else {
        redacted[key] = value;
      }
    });
    return redacted;
  }

  static String sanitizeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return redact(url);
    if (uri.queryParameters.isEmpty) return url;
    return uri.replace(queryParameters: const {}).toString();
  }
}
