import 'dart:convert';
import 'dart:js_interop';

// Minimal bindings to the few browser APIs the preview needs, through the
// SDK's own `dart:js_interop`, so the app needs no extra package.

@JS('window')
external _Window get _window;

extension type _Window(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);
  external void postMessage(JSAny? message, String targetOrigin);
  external _Window? get parent;
  external _Location get location;
}

extension type _Location(JSObject _) implements JSObject {
  external String get origin;
}

extension type _MessageEvent(JSObject _) implements JSObject {
  external String get origin;
  external JSAny? get data;
}

/// Receives preview documents from the Studio. Same-origin messages only, so
/// another site cannot drive the preview.
void listenToHost(void Function(Map<String, dynamic> message) onMessage) {
  final origin = _window.location.origin;
  _window.addEventListener(
    'message',
    ((JSObject e) {
      final event = _MessageEvent(e);
      if (event.origin != origin) return;
      final raw = event.data;
      if (raw == null || !raw.isA<JSString>()) return;
      try {
        final decoded = jsonDecode((raw as JSString).toDart);
        if (decoded is Map && decoded['type'] == 'dxp.preview') {
          onMessage(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Not a preview message.
      }
    }).toJS,
  );
}

/// Sends a message to the Studio page that hosts this preview.
void postToHost(Map<String, dynamic> message) {
  _window.parent?.postMessage(jsonEncode(message).toJS, _window.location.origin);
}
