import 'dart:typed_data';
import 'dart:ui' show Rect;

Future<void> savePdf({
  required Uint8List bytes,
  required String fileName,
  Rect? sharePositionOrigin,
}) {
  throw UnsupportedError(
    'Statement PDF save is not supported on this platform.',
  );
}
