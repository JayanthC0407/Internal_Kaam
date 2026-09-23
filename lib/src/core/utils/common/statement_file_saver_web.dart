import 'dart:typed_data';
import 'dart:ui' show Rect;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> saveStatement({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  Rect? sharePositionOrigin,
}) async {
  final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', safeName)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
