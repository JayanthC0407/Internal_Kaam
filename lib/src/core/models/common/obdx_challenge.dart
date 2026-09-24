import 'dart:convert';

/// OTP / step-up challenge from OBDX `X-Challenge` response header.
class ObdxChallenge {
  const ObdxChallenge({
    required this.authType,
    required this.referenceNo,
    this.attemptsLeft,
    this.resendsLeft,
    this.scope,
  });

  final String authType;
  final String referenceNo;
  final int? attemptsLeft;
  final int? resendsLeft;
  final String? scope;

  factory ObdxChallenge.fromJson(Map<String, dynamic> json) {
    return ObdxChallenge(
      authType: (json['authType'] ?? 'OTP').toString(),
      referenceNo: json['referenceNo']?.toString() ?? '',
      attemptsLeft: _asInt(json['attemptsLeft']),
      resendsLeft: _asInt(json['resendsLeft']),
      scope: json['scope']?.toString(),
    );
  }

  /// Value for the `X-Challenge_response` request header (OTP submit).
  String toChallengeResponseHeader(String otp) {
    return jsonEncode({
      'otp': otp,
      'referenceNo': referenceNo,
      'authType': authType,
    });
  }

  /// Payment step-up uses only `X-Challenge.referenceNo`.
  ///
  /// Do not fall back to `status.referenceNumber` — on `pay/network` that value
  /// is a different id than the OTP challenge reference.
  ///
  /// Ported from vendor branch — used by [TransferSubmitOutcome.tryParse]
  /// (own-account transfer).
  static ObdxChallenge? fromPaymentChallengeHeaders(dynamic headers) {
    final challenge = fromResponseHeaders(headers);
    if (challenge == null || challenge.referenceNo.isEmpty) return null;
    return challenge;
  }

  /// Parses `X-Challenge` from a wrapped OBDX HTTP response `headers` map.
  static ObdxChallenge? fromResponseHeaders(dynamic headers) {
    final raw = _headerValue(headers, 'X-Challenge');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ObdxChallenge.fromJson(decoded);
      }
      if (decoded is Map) {
        return ObdxChallenge.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Prefer `X-Challenge` header; fall back to `status.referenceNumber` (common on web
  /// when CORS does not expose the challenge header).
  static ObdxChallenge? fromResponse({
    required dynamic headers,
    required Map<String, dynamic> body,
  }) {
    final fromHeader = fromResponseHeaders(headers);
    if (fromHeader != null && fromHeader.referenceNo.isNotEmpty) {
      return fromHeader;
    }

    final status = body['status'];
    if (status is! Map) return null;
    final reference =
        (status['referenceNumber'] ?? status['referenceNo'])?.toString().trim();
    if (reference == null || reference.isEmpty) return null;

    final message = status['message'];
    final messageType = message is Map
        ? message['type']?.toString().toUpperCase()
        : null;
    if (messageType == 'ERROR') return null;

    return ObdxChallenge(
      authType: fromHeader?.authType ?? 'OTP',
      referenceNo: reference,
      attemptsLeft: fromHeader?.attemptsLeft,
      resendsLeft: fromHeader?.resendsLeft,
      scope: fromHeader?.scope,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _headerValue(dynamic headers, String name) {
    if (headers is! Map) return null;
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toString().toLowerCase() == target) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value != null) return value.toString();
      }
    }
    return null;
  }
}
