import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveStatement({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  Rect? sharePositionOrigin,
}) async {
  final dir = await getTemporaryDirectory();
  final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);

  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: mimeType, name: safeName),
        ],
        subject: safeName,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  } catch (_) {
    // Share sheet unavailable / cancelled after write — file is still on disk.
    // Treat as success so the UI does not show a false failure.
  }
}
