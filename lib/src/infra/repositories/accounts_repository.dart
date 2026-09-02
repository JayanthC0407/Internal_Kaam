import 'dart:convert';

import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/casa_account_detail.dart';
import 'package:ubci_bank/src/core/models/casa_transaction.dart';
import 'package:ubci_bank/src/core/models/statement_format.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_accounts_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

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

class AccountsRepository {
  AccountsRepository({required ObdxAccountsApi accountsApi})
      : _accountsApi = accountsApi;

  final ObdxAccountsApi _accountsApi;

  Future<ResponseHandler<CasaAccountsSummary>> fetchCasaAccounts() async {
    try {
      final result = await _accountsApi.fetchDemandDepositAccounts();
      return _parseSuccessBody(result, CasaAccountsSummary.fromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// CASA accounts eligible to settle a given transaction task — used by
  /// the loan repayment flow (`taskCode: 'LN_F_LRP'`) to populate the
  /// "pay from" account picker.
  Future<ResponseHandler<List<CasaAccount>>> fetchSettlementAccounts({
    required String taskCode,
  }) async {
    try {
      final result = await _accountsApi.fetchAccountsForTask(taskCode);
      return _parseSuccessBody(result, CasaAccount.listFromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<CasaAccountDetail>> fetchCasaAccountDetail(
    String accountId,
  ) async {
    try {
      final result = await _accountsApi.fetchDemandDepositAccount(accountId);
      return _parseSuccessBody(result, (body) {
        final detail = CasaAccountDetail.fromPayload(body);
        if (detail == null) {
          throw StateError('Empty account detail');
        }
        return detail;
      });
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<CasaTransactionsResult>> fetchCasaTransactions(
    String accountId, {
    CasaTransactionQuery query = const CasaTransactionQuery(),
  }) async {
    try {
      final result = await _accountsApi.fetchDemandDepositTransactions(
        accountId,
        queryParameters: query.toQueryParameters(),
      );
      return _parseSuccessBody(
        result,
        CasaTransactionsResult.fromPayload,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Available statement download formats (CSV/PDF/QIF/OFX per the
  /// `dda/v1/enumerations/mediatype` capture) — used to populate the
  /// format picker before downloading.
  Future<ResponseHandler<List<StatementFormat>>> fetchStatementFormats() async {
    try {
      final result = await _accountsApi.fetchMediaTypes();
      return _parseSuccessBody(result, StatementFormat.listFromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<StatementFile>> downloadStatement(
    String accountId, {
    required StatementFormat format,
    CasaTransactionQuery query = const CasaTransactionQuery(),
  }) async {
    try {
      final result = await _accountsApi.downloadStatement(
        accountId,
        media: format.mimeType,
        mediaFormat: format.code,
        queryParameters: query.toQueryParameters(),
      );
      if (result is! Success<List<int>> || result.data == null) {
        return _mapFailure(result);
      }

      final bytes = result.data!;
      final extension = format.fileExtension;
      final isPdf = extension == 'pdf';

      if (isPdf && _looksLikePdf(bytes)) {
        return ResponseHandler.success(
          StatementFile(
            bytes: bytes,
            fileName: _defaultFileName(accountId, extension),
            mimeType: format.mimeType,
          ),
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
            StatementFile(
              bytes: bytes,
              fileName: _defaultFileName(accountId, extension),
              mimeType: format.mimeType,
            ),
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

  /// Kept for any existing PDF-only call sites.
  Future<ResponseHandler<StatementFile>> downloadStatementPdf(
    String accountId, {
    CasaTransactionQuery query = const CasaTransactionQuery(),
  }) {
    return downloadStatement(
      accountId,
      format: const StatementFormat(code: 'pdf', mimeType: 'application/pdf'),
      query: query,
    );
  }

  static bool _looksLikePdf(List<int> bytes) {
    // Skip UTF-8 BOM if present.
    var offset = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      offset = 3;
    }
    if (bytes.length < offset + 4) return false;
    return bytes[offset] == 0x25 &&
        bytes[offset + 1] == 0x50 &&
        bytes[offset + 2] == 0x44 &&
        bytes[offset + 3] == 0x46; // %PDF
  }

  static Map<String, dynamic>? _tryJsonMap(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      final dynamic decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static StatementFile? _pdfFromJsonBytes(
    List<int> bytes, {
    required String mimeType,
  }) {
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
      final name = fileName.toLowerCase().endsWith('.pdf')
          ? fileName
          : '$fileName.pdf';
      return StatementFile(bytes: pdfBytes, fileName: name, mimeType: mimeType);
    } catch (_) {
      return null;
    }
  }

  static String? _findFileName(Map<String, dynamic> root) {
    const keys = [
      'fileName',
      'filename',
      'name',
      'documentName',
      'reportName',
    ];
    final direct = _firstString(root, keys);
    if (direct != null) return direct;
    for (final nestedKey in const [
      'fileDTO',
      'file',
      'document',
      'documentDTO',
      'statement',
      'report',
      'eStatement',
    ]) {
      final nested = root[nestedKey];
      if (nested is Map) {
        final name = _firstString(Map<String, dynamic>.from(nested), keys);
        if (name != null) return name;
      }
    }
    return null;
  }

  static String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Walks JSON for a base64 string that decodes to a PDF.
  static String? _findBase64Pdf(dynamic node, {int depth = 0}) {
    if (depth > 8 || node == null) return null;

    if (node is String) {
      final cleaned = node.replaceAll(RegExp(r'\s'), '');
      if (cleaned.length < 32) return null;
      // data:application/pdf;base64,....
      final dataUri = RegExp(
        r'^data:application/pdf;base64,(.+)$',
        caseSensitive: false,
      ).firstMatch(cleaned);
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

  static String _defaultFileName(String accountId, String extension) {
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final short = accountId.length > 8
        ? accountId.substring(accountId.length - 8)
        : accountId;
    return 'statement_${short}_$stamp.$extension';
  }

  Future<ResponseHandler<T>> _parseSuccessBody<T>(
    ResponseHandler<Map<String, dynamic>> result,
    T Function(Map<String, dynamic> body) parse,
  ) async {
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return _mapFailure(result);
    }

    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);

    if (statusCode != StatusCode.OK) {
      final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    if (ObdxApiUtils.hasErrorMessage(body)) {
      final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    try {
      final parsed = parse(body);
      return ResponseHandler.success(parsed, code: statusCode);
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
}
