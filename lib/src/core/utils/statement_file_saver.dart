import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:ubci_bank/src/core/utils/statement_file_saver_stub.dart'
    if (dart.library.html) 'package:ubci_bank/src/core/utils/statement_file_saver_web.dart'
    if (dart.library.io) 'package:ubci_bank/src/core/utils/statement_file_saver_io.dart'
    as impl;

/// Saves / shares a statement PDF on the current platform.
class StatementFileSaver {
  StatementFileSaver._();

  static Future<void> savePdf({
    required List<int> bytes,
    required String fileName,
    Rect? sharePositionOrigin,
  }) {
    return impl.savePdf(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
