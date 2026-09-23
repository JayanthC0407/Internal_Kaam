import 'dart:typed_data';
import 'dart:ui' show Rect;

Future<void> saveStatement({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  Rect? sharePositionOrigin,
}) {
  throw UnsupportedError(
    'Statement save is not supported on this platform.',
  );
}
