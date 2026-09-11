import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/l10n/error_localizations.dart';
import 'package:ubci_bank/src/core/constants/app_constants.dart';
import 'package:ubci_bank/src/core/models/obdx_error.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Parses Dio and OBDX payloads into [ObdxError] with l10n keys for UI.
class ObdxErrorMapper {
  ObdxErrorMapper._();

  static const _knownObdxCodes = <String, (String l10nKey, String fallback)>{
    'DIGX_AUTH_0001': ('errorInvalidCredentials', 'Invalid username or password.'),
    'DIGX_AUTH_0002': ('errorAccountLocked', 'Your account is locked. Please contact the bank.'),
    'DIGX_AUTH_0003': ('errorPasswordExpired', 'Your password has expired. Please reset your password.'),
    'DIGX_AUTH_0004': ('errorTooManyAttempts', 'Too many failed attempts. Please try again later.'),
    // Ported from vendor branch — first-time Login Flow Wizard incomplete.
    // Normally handled by LoginWizardRepository.checkGate() before this
    // code would reach a generic error path; kept here as a safety net.
    'DIGX_CMN_0096': (
      'lfwRequired',
      'Please complete first-time login setup before continuing.',
    ),
    'DIGX_AUTH_0005': (
      'errorSessionExpired',
      'For your security, you have been signed out. Please sign in again.',
    ),
    /// Invalid / expired JWT on authenticated APIs (e.g. CASA demandDeposit).
    'DIGX_AU_035': (
      'errorSessionExpired',
      'For your security, you have been signed out. Please sign in again.',
    ),
    'DIGX_AU_001': (
      'errorAuthFailed',
      'Authentication failed. Please sign in again.',
    ),
    'DIGX_AU_002': (
      'errorAuthFailed',
      'Authentication failed. Please sign in again.',
    ),
    'DIGX_AU_003': (
      'errorForbidden',
      'You do not have permission to perform this action.',
    ),
    'DIGX_AUTH_0006': (
      'errorInvalidCredentials',
      'Invalid username or password.',
    ),
    'DIGX_AUTH_0007': (
      'errorAccountLocked',
      'Your account is locked. Please contact the bank.',
    ),
    'DIGX_TFA_0001': (
      'errorOtpInvalid',
      'The verification code is incorrect. Please try again.',
    ),
    'DIGX_TFA_0002': (
      'errorTooManyAttempts',
      'Too many failed attempts. Please try again later.',
    ),
    'DIGX_TFA_0003': (
      'otpResendUnavailable',
      'Resend is not available yet. Please try again later.',
    ),
    'DIGX_AUTH_0012': (
      'errorTooManyAttempts',
      'You have exceeded the maximum allowed limit for generating authorization tokens. Please try again later.',
    ),
    'DIGX_TFA_0004': (
      'errorOtpInvalid',
      'The verification code is incorrect. Please try again.',
    ),
    'DIGX_DB_AUTH_005': (
      'errorBiometricAccessPoint',
      'Mobile quick access is not enabled for your account on the server. '
          'Ask your bank to enable the Mobile App touch point for your user.',
    ),
    'INVALID_CREDENTIALS': ('errorInvalidCredentials', 'Invalid username or password.'),
    'USER_LOCKED': ('errorAccountLocked', 'Your account is locked. Please contact the bank.'),
    'PASSWORD_EXPIRED': ('errorPasswordExpired', 'Your password has expired. Please reset your password.'),
  };

  /// Profile `/me` responses — maps OTP challenge failures separately from password expiry.
  static ObdxError fromProfileResponse(
    int? statusCode,
    dynamic body, {
    String? requestId,
  }) {
    if (statusCode == 417) {
      final parsed = fromPayload(body, statusCode: statusCode, requestId: requestId);
      final code = parsed?.obdxCode;
      // Wrong OTP / TFA failures (e.g. DIGX_TFA_0004) — keep server detail when present.
      if (parsed != null &&
          code != null &&
          code.startsWith('DIGX_TFA_')) {
        return parsed;
      }
      if (code == 'DIGX_AUTH_0003' ||
          (parsed?.detail ?? '').toUpperCase().contains('EXPECTATION_FAILED')) {
        final detail = parsed?.detail;
        return ObdxError(
          category: ObdxErrorCategory.validation,
          l10nKey: 'errorOtpInvalid',
          userMessage: (detail != null && detail.isNotEmpty)
              ? detail
              : 'The verification code is incorrect. Please try again.',
          detail: detail,
          httpStatusCode: statusCode,
          obdxCode: code,
          requestId: requestId,
        );
      }
    }
    return fromHttpResponse(statusCode, body, requestId: requestId);
  }

  /// Prefer for OTP / TFA endpoints that use HTTP 417 for both challenge and failures.
  static ObdxError fromChallengeResponse(
    int? statusCode,
    dynamic body, {
    String? requestId,
  }) {
    final map = ObdxApiUtils.asMap(body);
    final parsed = fromPayload(body, statusCode: statusCode, requestId: requestId);
    if (parsed != null) {
      // Prefer exact server title/detail for TFA and validation errors.
      final detail = parsed.detail?.trim();
      if (detail != null && detail.isNotEmpty) {
        return ObdxError(
          category: parsed.category,
          httpStatusCode: statusCode ?? parsed.httpStatusCode,
          obdxCode: parsed.obdxCode,
          detail: detail,
          l10nKey: parsed.l10nKey ?? 'errorOtpInvalid',
          userMessage: detail,
          requestId: requestId ?? parsed.requestId,
        );
      }
      return parsed;
    }
    if (statusCode == 417 || ObdxApiUtils.hasErrorMessage(map)) {
      return _err(
        ObdxErrorCategory.validation,
        l10nKey: 'errorOtpInvalid',
        fallback: 'The verification code is incorrect. Please try again.',
        httpStatusCode: statusCode,
        requestId: requestId,
      );
    }
    return fromHttpResponse(statusCode, body, requestId: requestId);
  }

  static ObdxError fromDioException(DioException error) {
    final requestId = _readRequestId(error.response?.headers.map);

    switch (error.type) {
      case DioExceptionType.cancel:
        return _err(
          ObdxErrorCategory.cancelled,
          l10nKey: 'errorCancelled',
          fallback: 'Request was cancelled.',
          requestId: requestId,
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return _err(
          ObdxErrorCategory.timeout,
          l10nKey: 'errorTimeout',
          fallback:
              'The banking service is not responding. Please try again later.',
          requestId: requestId,
        );
      case DioExceptionType.connectionError:
        final refused = _isConnectionRefused(error);
        return _err(
          refused ? ObdxErrorCategory.server : ObdxErrorCategory.network,
          l10nKey: refused ? 'errorServerUnavailable' : 'errorNetwork',
          fallback: refused
              ? 'The banking service is temporarily unavailable. Please try again later.'
              : 'Unable to connect. Please check your internet connection and try again.',
          requestId: requestId,
        );
      case DioExceptionType.badCertificate:
        return _err(
          ObdxErrorCategory.certificate,
          l10nKey: 'errorBadCertificate',
          fallback:
              'Secure connection could not be verified. Please update the app or try again later.',
          requestId: requestId,
        );
      case DioExceptionType.badResponse:
        return fromHttpResponse(
          error.response?.statusCode,
          error.response?.data,
          requestId: requestId,
        );
      case DioExceptionType.unknown:
        if (error.message?.contains(AppConstants.socketException) ?? false) {
          return _err(
            ObdxErrorCategory.network,
            l10nKey: 'errorNetwork',
            fallback:
                'Unable to connect. Please check your internet connection and try again.',
            requestId: requestId,
          );
        }
        return _err(
          ObdxErrorCategory.unknown,
          l10nKey: 'errorUnexpected',
          fallback: 'An unexpected error occurred. Please try again.',
          requestId: requestId,
        );
    }
  }

  static ObdxError fromHttpResponse(
    int? statusCode,
    dynamic body, {
    String? requestId,
  }) {
    // Ported from vendor branch — a raw HTML body (gateway/WAF error page)
    // skips payload parsing entirely and goes straight to the generic,
    // status-code-derived error.
    if (_isHtmlBody(body)) {
      return _fromStatusCodeOnly(statusCode, requestId: requestId);
    }
    final parsed = fromPayload(body, statusCode: statusCode, requestId: requestId);
    if (parsed != null) return parsed;
    return _fromStatusCodeOnly(statusCode, requestId: requestId);
  }

  static ObdxError? fromPayload(
    dynamic body, {
    int? statusCode,
    String? requestId,
  }) {
    final map = _asMap(body);
    if (map.isEmpty) return null;

    final obdxCode = _extractObdxCode(map);
    final detail = _extractDetail(map);
    final mapped = _mapKnownCode(obdxCode, detail);
    if (mapped != null) {
      return ObdxError(
        category: _categoryForStatus(statusCode, obdxCode),
        httpStatusCode: statusCode,
        obdxCode: obdxCode,
        detail: detail,
        l10nKey: mapped.$1,
        userMessage: mapped.$2,
        requestId: requestId,
      );
    }

    if (detail != null && detail.isNotEmpty) {
      final sanitized = _sanitizeServerDetail(detail);
      // Ported from vendor branch: an HTML-only detail sanitizes to null —
      // fall through to the generic status-code-based error instead of a
      // null/blank user message.
      if (sanitized == null) return null;
      return ObdxError(
        category: _categoryForStatus(statusCode, obdxCode),
        httpStatusCode: statusCode,
        obdxCode: obdxCode,
        detail: sanitized,
        userMessage: sanitized,
        requestId: requestId,
      );
    }

    return null;
  }

  static String messageFromBody(
    dynamic body, {
    int? statusCode,
    AppLocalizations? l10n,
  }) {
    final error = fromHttpResponse(statusCode, body);
    if (l10n != null) return l10n.messageForObdxError(error);
    return error.userMessage;
  }

  static bool _isConnectionRefused(DioException error) {
    final combined =
        '${error.message ?? ''} ${error.error ?? ''}'.toLowerCase();
    return combined.contains('connection refused');
  }

  static ObdxError _err(
    ObdxErrorCategory category, {
    required String l10nKey,
    required String fallback,
    String? requestId,
    int? httpStatusCode,
    String? obdxCode,
  }) {
    return ObdxError(
      category: category,
      l10nKey: l10nKey,
      userMessage: fallback,
      requestId: requestId,
      httpStatusCode: httpStatusCode,
      obdxCode: obdxCode,
    );
  }

  static String? _readRequestId(Map<String, List<String>>? headers) {
    if (headers == null) return null;
    final values = headers[AppConstants.xRequestId];
    if (values != null && values.isNotEmpty) return values.first;
    return null;
  }

  static Map<String, dynamic> _asMap(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    if (body is String && body.trim().isNotEmpty) {
      // Ported from vendor branch: a gateway/WAF error page (HTML, not JSON)
      // must never be wrapped as {'message': <raw html>} — that would surface
      // the whole page source as the user-facing error message below.
      if (_isHtmlBody(body)) return {};
      try {
        final decoded = jsonDecode(body);
        return ObdxApiUtils.asMap(decoded);
      } catch (_) {
        if (_isHtmlBody(body)) return {};
        return {'message': body.trim()};
      }
    }
    return {};
  }

  /// Ported from vendor branch — detects an HTML error page (e.g. a load
  /// balancer/WAF block page) so it's never surfaced as a user-facing
  /// error message or stored as the parsed error "detail".
  static bool _isHtmlBody(dynamic body) {
    if (body is! String) return false;
    final trimmed = body.trimLeft();
    if (trimmed.isEmpty || !trimmed.startsWith('<')) return false;
    final lower = trimmed.toLowerCase();
    return lower.startsWith('<!doctype') ||
        lower.startsWith('<html') ||
        lower.contains('<html') ||
        lower.contains('</html>') ||
        lower.contains('<body');
  }

  static String? _extractObdxCode(Map<String, dynamic> json) {
    // Prefer DIGX_* from validationError[] over wrapper codes like "10011".
    final validation = _firstValidationError(json);
    if (validation != null) {
      final code = validation['errorCode']?.toString().trim();
      if (code != null && code.isNotEmpty && code != '10011') {
        return code;
      }
    }

    final topMessage = json['message'];
    if (topMessage is Map) {
      final msgCode = topMessage['code'];
      if (msgCode != null &&
          msgCode.toString().isNotEmpty &&
          msgCode.toString() != '10011') {
        return msgCode.toString();
      }
    }

    final status = json['status'];
    if (status is Map) {
      final message = status['message'];
      if (message is Map) {
        final msgCode = message['code'];
        if (msgCode != null && msgCode.toString().isNotEmpty) {
          return msgCode.toString();
        }
      }
      final code = status['code'] ?? status['errorCode'];
      if (code != null && code.toString().isNotEmpty) {
        return code.toString();
      }
    }
    for (final key in ['code', 'errorCode', 'error_code']) {
      final value = json[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static String? _extractDetail(Map<String, dynamic> json) {
    final validation = _firstValidationError(json);
    if (validation != null) {
      for (final key in ['errorMessage', 'detail', 'message', 'title']) {
        final value = validation[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }

    final status = json['status'];
    if (status is Map) {
      final message = status['message'];
      if (message is Map) {
        for (final key in ['detail', 'summary', 'title', 'message']) {
          final value = message[key]?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
      } else if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }

    // OBDX often returns a top-level message object on failures:
    // { "title": "...", "detail": "...", "code": "DIGX_PROD_DEF_0000", "type": "ERROR" }
    // or nested under "message".
    final topMessage = json['message'];
    if (topMessage is Map) {
      for (final key in ['detail', 'summary', 'title', 'message']) {
        final value = topMessage[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }

    final errors = json['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map) {
        for (final key in ['detail', 'message', 'summary', 'title']) {
          final value = first[key]?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
      } else if (first != null && first.toString().trim().isNotEmpty) {
        return first.toString().trim();
      }
    }

    for (final key in [
      'errorMessage',
      'error',
      'detail',
      'description',
      'title',
    ]) {
      final raw = json[key];
      if (raw is Map) continue;
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    // Avoid Map.toString() for "message" — handled above when it is an object.
    final message = json['message'];
    if (message != null && message is! Map) {
      final value = message.toString().trim();
      if (value.isNotEmpty) return value;
    }

    return null;
  }

  static Map<String, dynamic>? _firstValidationError(Map<String, dynamic> json) {
    Map<String, dynamic>? from(dynamic container) {
      if (container is! Map) return null;
      final list =
          container['validationError'] ?? container['validationErrors'];
      if (list is! List || list.isEmpty) return null;
      final first = list.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
      return null;
    }

    return from(json['message']) ?? from(json);
  }

  static String? _sanitizeServerDetail(String detail) {
    // Ported from vendor branch — never surface an HTML fragment embedded
    // in an otherwise-valid JSON error body (e.g. a "message" field that
    // itself contains a gateway's HTML snippet) as the user-facing message.
    if (_isHtmlBody(detail)) return null;
    final lower = detail.toLowerCase();
    if (lower.contains('cannot construct instance') ||
        lower.contains('deserialize from string value') ||
        lower.contains('through reference chain') ||
        lower.startsWith('{title:') ||
        lower.contains('digx_prod_def_0000')) {
      return 'Registration could not be processed. Please check your details and try again.';
    }
    return detail;
  }

  /// Codes whose API detail is technical — always use the localized fallback.
  static const _preferLocalizedFallbackCodes = {
    'DIGX_AU_035',
    'DIGX_AUTH_0005',
  };

  static (String, String)? _mapKnownCode(String? obdxCode, String? detail) {
    if (obdxCode != null) {
      final mapped = _knownObdxCodes[obdxCode];
      if (mapped != null) {
        if (_preferLocalizedFallbackCodes.contains(obdxCode)) {
          return mapped;
        }
        // Prefer server title/detail when present (exact API wording).
        if (detail != null && detail.trim().isNotEmpty) {
          return (mapped.$1, detail.trim());
        }
        return mapped;
      }
      // DIGX_PROD_DEF_0000 / unknown DIGX_TFA_* — prefer API title/detail.
      if (obdxCode == 'DIGX_PROD_DEF_0000' || obdxCode.startsWith('DIGX_TFA_')) {
        return null;
      }
    }
    if (detail == null) return null;

    final lower = detail.toLowerCase();
    if (lower.contains('invalid authentication token') ||
        lower.contains('invalid auth token')) {
      return _knownObdxCodes['DIGX_AU_035']!;
    }
    if (lower.contains('invalid') &&
        (lower.contains('credential') ||
            lower.contains('password') ||
            lower.contains('username') ||
            lower.contains('otp') ||
            lower.contains('verification'))) {
      return (
        'errorOtpInvalid',
        'The verification code is incorrect. Please try again.',
      );
    }
    if (lower.contains('locked')) {
      return _knownObdxCodes['USER_LOCKED']!;
    }
    if (lower.contains('expired') && lower.contains('password')) {
      return _knownObdxCodes['PASSWORD_EXPIRED']!;
    }
    return null;
  }

  static ObdxErrorCategory _categoryForStatus(int? statusCode, String? obdxCode) {
    if (obdxCode != null && _knownObdxCodes.containsKey(obdxCode)) {
      if (obdxCode.contains('AUTH') ||
          obdxCode.contains('CREDENTIAL') ||
          obdxCode.startsWith('DIGX_AU_')) {
        return ObdxErrorCategory.unauthorized;
      }
    }

    switch (statusCode) {
      case StatusCode.BAD_REQUEST:
      case StatusCode.UNPROCESSABLE_ENTITY:
        return ObdxErrorCategory.validation;
      case StatusCode.UNAUTHORIZED:
        return ObdxErrorCategory.unauthorized;
      case StatusCode.FORBIDDEN:
        return ObdxErrorCategory.forbidden;
      case StatusCode.NOT_FOUND:
        return ObdxErrorCategory.notFound;
      default:
        if (statusCode != null && statusCode >= 500) {
          return ObdxErrorCategory.server;
        }
        return ObdxErrorCategory.unknown;
    }
  }

  static ObdxError _fromStatusCodeOnly(int? statusCode, {String? requestId}) {
    final category = _categoryForStatus(statusCode, null);
    final (l10nKey, fallback) = switch (statusCode) {
      StatusCode.BAD_REQUEST => (
          'errorInvalidRequest',
          'Invalid request. Please check your input.',
        ),
      StatusCode.UNAUTHORIZED => (
          'errorAuthFailed',
          'Authentication failed. Please sign in again.',
        ),
      StatusCode.FORBIDDEN => (
          'errorForbidden',
          'You do not have permission to perform this action.',
        ),
      StatusCode.NOT_FOUND => (
          'errorNotFound',
          'The requested resource was not found.',
        ),
      StatusCode.CONFLICT => (
          'errorUserAlreadyExists',
          'An account with this username already exists.',
        ),
      423 => (
          'errorAccountLocked',
          'Your account is locked. Please contact the bank.',
        ),
      _ when statusCode != null && statusCode >= 500 => (
          'errorServerUnavailable',
          'Service is temporarily unavailable. Please try again later.',
        ),
      _ => ('errorGeneric', 'Something went wrong. Please try again.'),
    };

    return ObdxError(
      category: category,
      httpStatusCode: statusCode,
      l10nKey: l10nKey,
      userMessage: fallback,
      requestId: requestId,
    );
  }
}
