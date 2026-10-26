import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/statement_format.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';

// The shared download decoder (moved unchanged from AccountsRepository,
// used by account statements and Bill Payment History).

const _pdf = StatementFormat(code: 'pdf', mimeType: 'application/pdf');
const _csv = StatementFormat(code: 'csv', mimeType: 'text/csv');
final _pdfBytes = [...utf8.encode('%PDF-1.4'), ...List.filled(40, 32)];

ResponseHandler<StatementFile> _decode(List<int> bytes, StatementFormat format) =>
    decodeStatementDownload(ResponseHandler.success(bytes, code: 200), format: format, fileName: 'f.${format.code}');

void main() {
  test('real PDF bytes are kept as they are', () {
    final r = _decode(_pdfBytes, _pdf) as Success<StatementFile>;
    expect(r.data!.bytes, _pdfBytes);
    expect(r.data!.fileName, 'f.pdf');
    expect(r.data!.mimeType, 'application/pdf');
  });

  test('a PDF wrapped in JSON (base64) is dug out, with its file name', () {
    // The name is read from the top level or known keys (fileDTO, document…);
    // the PDF itself can be nested anywhere.
    final body = utf8.encode(jsonEncode({
      'fileName': 'history',
      'contentDTOList': [
        {'content': base64Encode(_pdfBytes)},
      ],
    }));
    final r = _decode(body, _pdf) as Success<StatementFile>;
    expect(r.data!.bytes, _pdfBytes);
    expect(r.data!.fileName, 'history.pdf');
  });

  test('CSV text is accepted as-is', () {
    final csv = utf8.encode('Date,Biller,Amount\n2026-10-01,Water,12.00\n');
    final r = _decode(csv, _csv) as Success<StatementFile>;
    expect(utf8.decode(r.data!.bytes), startsWith('Date,Biller'));
  });

  test('an OBDX error disguised as a file becomes an error', () {
    final err = utf8.encode(jsonEncode({
      'status': {
        'result': 'FAILURE',
        'message': {'type': 'ERROR', 'code': 'DIGX_X', 'title': 'No records'},
      },
    }));
    expect(_decode(err, _csv), isA<Error<StatementFile>>());
    expect(_decode(err, _pdf), isA<Error<StatementFile>>());
  });

  test('a failed call passes through', () {
    final r = decodeStatementDownload(
      ResponseHandler<List<int>>.error(500, 'boom'),
      format: _pdf,
      fileName: 'x.pdf',
    );
    expect(r, isA<Error<StatementFile>>());
  });

  test('file name: prefix, last 8 of the id, today, extension', () {
    expect(statementFileName('ACCOUNT123456789', 'csv'), matches(RegExp(r'^statement_23456789_\d{4}-\d{2}-\d{2}\.csv$')));
    expect(statementFileName('CPR', 'pdf', prefix: 'bill_payments'), matches(RegExp(r'^bill_payments_CPR_\d{4}-\d{2}-\d{2}\.pdf$')));
  });
}
