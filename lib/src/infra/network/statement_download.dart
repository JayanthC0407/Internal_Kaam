import 'dart:convert';

import 'package:ubci_bank/src/core/models/common/statement_format.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Shared statement/file download handling — the app's counterpart of
/// OBDX's one framework `baseService.downloadFile`
/// (framework/js/base-models/service-base.js:736), which account
/// transactions, Bill Payment History and card statements all use.
/// Moved unchanged from `AccountsRepository` (2026-10-23).

/// A downloaded file, ready for `StatementFileSaver`.
class StatementFile {
  const StatementFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}

/// `<prefix>_<last 8 of id>_<yyyy-mm-dd>.<ext>`.
String statementFileName(String id, String extension, {String prefix = 'statement'}) {
  final stamp = DateTime.now().toIso8601String().split('T').first;
  final short = id.length > 8 ? id.substring(id.length - 8) : id;
  return '${prefix}_${short}_$stamp.$extension';
}

/// Turns the raw bytes of a `media`/`mediaFormat` download into a
/// [StatementFile], or the OBDX error hidden inside them.
///
/// - PDF bytes (`%PDF`) are used as they are.
/// - Some hosts answer a PDF request with JSON (base64 / nested DTO); the
///   PDF is dug out of it.
/// - CSV/QIF/OFX are plain text, accepted unless the body is an OBDX error
///   payload disguised as bytes.
ResponseHandler<StatementFile> decodeStatementDownload(
  ResponseHandler<List<int>> result, {
  required StatementFormat format,
  required String fileName,
}) {
  try {
    if (result is! Success<List<int>> || result.data == null) {
      return _mapFailure(result);
    }

    final bytes = result.data!;
    final isPdf = format.fileExtension == 'pdf';

    if (isPdf && _looksLikePdf(bytes)) {
      return ResponseHandler.success(
        StatementFile(bytes: bytes, fileName: fileName, mimeType: format.mimeType),
        code: result.code,
      );
    }

    if (isPdf) {
      // Some hosts return JSON (base64 / nested DTO) even with
      // ResponseType.bytes — confirmed pattern for the PDF format only.
      final decoded = _pdfFromJsonBytes(bytes, mimeType: format.mimeType);
      if (decoded != null) {
        return ResponseHandler.success(decoded, code: result.code);
      }
    } else {
      // CSV/QIF/OFX are plain text — accept as-is unless the body is
      // actually an OBDX error payload disguised as bytes.
      final maybeError = _tryJsonMap(bytes);
      if (maybeError == null || !ObdxApiUtils.hasErrorMessage(maybeError)) {
        return ResponseHandler.success(
          StatementFile(bytes: bytes, fileName: fileName, mimeType: format.mimeType),
          code: result.code,
        );
      }
    }

    // OBDX error JSON without a usable file payload.
    final errorBody = _tryJsonMap(bytes);
    if (errorBody != null && ObdxApiUtils.hasErrorMessage(errorBody)) {
      final obdxError = ObdxErrorMapper.fromHttpResponse(
        result.code == 0 ? 200 : result.code,
        errorBody,
      );
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? result.code,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    return ResponseHandler.exceptionError();
  } catch (_) {
    return ResponseHandler.exceptionError();
  }
}

ResponseHandler<T> _mapFailure<T>(ResponseHandler<dynamic> result) {
  if (result is Error) {
    return ResponseHandler.error(
      result.code,
      result.error,
      requestId: result.requestId,
      obdxError: result.obdxError,
    );
  }
  if (result is NetworkError) {
    return ResponseHandler.networkError(obdxError: result.obdxError);
  }
  return ResponseHandler.exceptionError();
}

bool _looksLikePdf(List<int> bytes) {
  // Skip UTF-8 BOM if present.
  var offset = 0;
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    offset = 3;
  }
  if (bytes.length < offset + 4) return false;
  return bytes[offset] == 0x25 &&
      bytes[offset + 1] == 0x50 &&
      bytes[offset + 2] == 0x44 &&
      bytes[offset + 3] == 0x46; // %PDF
}

Map<String, dynamic>? _tryJsonMap(List<int> bytes) {
  try {
    final text = utf8.decode(bytes);
    final dynamic decoded = jsonDecode(text);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}

StatementFile? _pdfFromJsonBytes(List<int> bytes, {required String mimeType}) {
  try {
    final map = _tryJsonMap(bytes);
    if (map == null) return null;
    if (ObdxApiUtils.hasErrorMessage(map)) return null;

    final fileName = _findFileName(map) ?? 'statement.pdf';
    final raw = _findBase64Pdf(map);
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'\s'), '');
    final pdfBytes = base64Decode(cleaned);
    if (!_looksLikePdf(pdfBytes)) return null;
    final name = fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf';
    return StatementFile(bytes: pdfBytes, fileName: name, mimeType: mimeType);
  } catch (_) {
    return null;
  }
}

String? _findFileName(Map<String, dynamic> root) {
  const keys = ['fileName', 'filename', 'name', 'documentName', 'reportName'];
  final direct = _firstString(root, keys);
  if (direct != null) return direct;
  for (final nestedKey in const ['fileDTO', 'file', 'document', 'documentDTO', 'statement', 'report', 'eStatement']) {
    final nested = root[nestedKey];
    if (nested is Map) {
      final name = _firstString(Map<String, dynamic>.from(nested), keys);
      if (name != null) return name;
    }
  }
  return null;
}

String? _firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// Walks JSON for a base64 string that decodes to a PDF.
String? _findBase64Pdf(dynamic node, {int depth = 0}) {
  if (depth > 8 || node == null) return null;

  if (node is String) {
    final cleaned = node.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length < 32) return null;
    // data:application/pdf;base64,....
    final dataUri = RegExp(r'^data:application/pdf;base64,(.+)$', caseSensitive: false).firstMatch(cleaned);
    final candidate = dataUri?.group(1) ?? cleaned;
    try {
      final bytes = base64Decode(candidate);
      if (_looksLikePdf(bytes)) return candidate;
    } catch (_) {}
    return null;
  }

  if (node is Map) {
    // Prefer known content keys first.
    for (final key in const [
      'content',
      'fileContent',
      'contentInBase64',
      'base64Content',
      'pdfContent',
      'data',
      'pdf',
      'bytes',
      'fileData',
      'documentContent',
    ]) {
      if (!node.containsKey(key)) continue;
      final found = _findBase64Pdf(node[key], depth: depth + 1);
      if (found != null) return found;
    }
    for (final value in node.values) {
      final found = _findBase64Pdf(value, depth: depth + 1);
      if (found != null) return found;
    }
  }

  if (node is List) {
    for (final value in node) {
      final found = _findBase64Pdf(value, depth: depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}
