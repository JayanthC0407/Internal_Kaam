import 'dart:convert';
import 'dart:math';

import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// `X-BATCH_TYPE` values the OBDX batch servlet accepts for the calls the
/// app makes (the servlet rejects a batch without one — `DIGX_BT_0002`).
abstract final class ObdxBatchType {
  /// Multiple Transfers, checked with `X-Validate-Only` before the review.
  static const validateMultipleTransfers = 'CMFT';

  /// Multiple Transfers, submitted.
  static const multipleTransfers = 'MFT';
}

/// One request inside an OBDX batch: the same call the app would make on
/// its own, sent to `/digx-{domain}/batch` with the others.
class ObdxBatchItem {
  const ObdxBatchItem({
    required this.method,
    required this.uri,
    required this.applicationId,
    this.body,
    this.headers = const {},
  });

  /// `POST`, `PUT`, …
  final String method;

  /// The path inside the application, e.g. `/payments/pay/network` — no
  /// `/digx-payments/payment/v1` prefix; [applicationId] says where it goes.
  final String uri;

  /// `digx-{domain}/{application}`, e.g. `digx-payments/payment`.
  final String applicationId;

  final Map<String, dynamic>? body;

  /// Per-request headers, e.g. `X-Validate-Only`.
  final Map<String, String> headers;
}

/// The multipart body the OBDX web app builds for a batch, byte for byte
/// (`service-base.js` `buildBatchRequest`; parsed on the server by
/// `MultipartProcessor` with commons-fileupload):
///
/// ```text
/// --{boundary}
/// Content-Id: 0
/// Content-Type: application/json
/// Application-Id: digx-payments/payment
///
/// POST /payments/pay/network HTTP/1.1
///
/// {"amount": …}
/// --{boundary}--
/// ```
///
/// The web adds an `x-nonce` per part because its session uses nonces; the
/// app's JWT session does not, as with every other call it makes.
abstract final class ObdxBatchEncoder {
  /// A boundary in the web's shape (`--OBDXbatch` + 10 random characters).
  static String newBoundary([Random? random]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = random ?? Random.secure();
    return '--OBDXbatch${List.generate(10, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  static String encode(List<ObdxBatchItem> items, String boundary) {
    final out = StringBuffer();
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      out.write('--$boundary\r\n');
      out.write('Content-Id: $i\r\n');
      out.write('Content-Type: application/json\r\n');
      item.headers.forEach((key, value) => out.write('$key: $value\r\n'));
      out.write('Application-Id: ${item.applicationId}\r\n');
      out.write('\r\n${item.method} ${item.uri} HTTP/1.1\r\n');
      if (item.body != null) out.write('\r\n${jsonEncode(item.body)}\r\n');
    }
    out.write('--$boundary--\r\n');
    return out.toString();
  }
}

/// One answer in a batch response (`batchDetailResponseDTOList[]`).
class ObdxBatchItemResult {
  const ObdxBatchItemResult({
    required this.sequenceId,
    required this.status,
    required this.body,
    this.headers = const {},
  });

  /// The request's position in the batch (its `Content-Id`).
  final int sequenceId;

  /// The HTTP status that request would have had on its own.
  final int status;

  /// Its JSON body (`responseText`, decoded).
  final Map<String, dynamic> body;
  final Map<String, String> headers;

  /// 200 done, 202 accepted — waiting for an approver (OBDX's web treats
  /// both as success).
  bool get succeeded => status == 200 || status == 201 || status == 202;

  /// Sent to an approver rather than processed.
  bool get pendingApproval =>
      status == 202 || headers['APPROVAL_STATUS']?.toUpperCase() == 'INITIATED';

  /// The answers in request order. Unreadable entries are skipped, so a
  /// caller matches them to its requests by [sequenceId], not by index.
  static List<ObdxBatchItemResult> listFromPayload(Map<String, dynamic> body) {
    final raw = body['batchDetailResponseDTOList'];
    final list = <ObdxBatchItemResult>[
      if (raw is List)
        for (final entry in raw)
          if (entry is Map)
            if (_parse(Map<String, dynamic>.from(entry)) case final item?) item,
    ];
    list.sort((a, b) => a.sequenceId.compareTo(b.sequenceId));
    return list;
  }

  static ObdxBatchItemResult? _parse(Map<String, dynamic> entry) {
    final sequence = int.tryParse('${entry['sequenceId'] ?? ''}'.trim());
    final status = entry['status'] is num
        ? (entry['status'] as num).toInt()
        : int.tryParse('${entry['status'] ?? ''}');
    if (sequence == null || status == null) return null;
    Map<String, dynamic> parsedBody;
    try {
      parsedBody = ObdxApiUtils.asMap(entry['responseObj'] ?? entry['responseText']);
    } catch (_) {
      parsedBody = const {};
    }
    final rawHeaders = entry['header'];
    return ObdxBatchItemResult(
      sequenceId: sequence,
      status: status,
      body: parsedBody,
      headers: {
        if (rawHeaders is Map)
          for (final e in rawHeaders.entries)
            if (e.value != null) '${e.key}': '${e.value}',
      },
    );
  }
}
