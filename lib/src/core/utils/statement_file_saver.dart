import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:ubci_bank/src/core/utils/statement_file_saver_stub.dart'
    if (dart.library.html) 'package:ubci_bank/src/core/utils/statement_file_saver_web.dart'
    if (dart.library.io) 'package:ubci_bank/src/core/utils/statement_file_saver_io.dart'
    as impl;

/// Saves / shares a downloaded account statement on the current platform.
class StatementFileSaver {
  StatementFileSaver._();

  static Future<void> saveStatement({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    Rect? sharePositionOrigin,
  }) {
    return impl.saveStatement(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      mimeType: mimeType,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Kept for any existing PDF-only call sites.
  static Future<void> savePdf({
    required List<int> bytes,
    required String fileName,
    Rect? sharePositionOrigin,
  }) {
    return saveStatement(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/pdf',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
