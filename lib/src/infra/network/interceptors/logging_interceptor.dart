import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/core/constants/adlog.dart';
import 'package:ubci_bank/src/core/utils/log_redactor.dart';

/// Debug-only HTTP logging for all Dio traffic.
///
/// Logs method/URL, redacted headers, request payload, and response/error bodies.
/// Attached only when [kDebugMode] in [ObdxDioClient].
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final url = LogRedactor.sanitizeUrl(
        '${options.baseUrl}${options.path}',
      );
      adLog('HTTP → ${options.method} $url');
      _logHeaders('request', options.headers);
      _logPayload('request body', options.data);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      adLog(
        'HTTP ← ${response.statusCode} ${response.requestOptions.path}',
      );
      _logPayload('response body', response.data);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final status = err.response?.statusCode;
      final optional = err.requestOptions.extra['optional'] == true;
      if (optional && status == 404) {
        adLog(
          'HTTP (optional, 404) ${err.requestOptions.path} — trying fallback if any',
        );
      } else {
        final type = err.type.name;
        adLog(
          'HTTP ✕ $type ${status ?? '-'} ${err.requestOptions.path}',
        );
        if (err.message != null && err.message!.isNotEmpty) {
          adLog(LogRedactor.redact(err.message!));
        }
        _logPayload('error body', err.response?.data);
      }
    }
    handler.next(err);
  }

  void _logHeaders(String label, Map<String, dynamic> headers) {
    if (headers.isEmpty) return;
    adLog('$label headers: ${LogRedactor.redactHeaders(headers)}');
  }

  void _logPayload(String label, dynamic data) {
    if (data == null) {
      adLog('$label: (empty)');
      return;
    }
    if (data is List<int>) {
      final preview = data.length >= 4
          ? data.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')
          : '';
      adLog('$label: [bytes:${data.length}${preview.isEmpty ? '' : ' head=$preview'}]');
      return;
    }
    if (data is String && data.trim().isEmpty) {
      adLog('$label: (empty)');
      return;
    }
    adLog('$label: ${LogRedactor.redactPayload(data)}');
  }
}
