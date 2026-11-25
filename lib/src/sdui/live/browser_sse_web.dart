import 'dart:js_interop';

// Minimal bindings to the browser's EventSource, through the SDK's own
// `dart:js_interop`, so the app needs no extra package (as the preview bridge).

@JS('EventSource')
extension type _EventSource._(JSObject _) implements JSObject {
  external factory _EventSource(String url);
  external void addEventListener(String type, JSFunction listener);
  external void close();

  /// 0 connecting, 1 open, 2 closed.
  external int get readyState;
}

extension type _MessageEvent(JSObject _) implements JSObject {
  external JSAny? get data;
}

/// An open browser SSE connection.
abstract class BrowserSse {
  void close();
}

class _Sse implements BrowserSse {
  _Sse(this._source);

  final _EventSource _source;

  @override
  void close() => _source.close();
}

/// Opens [url] with EventSource and reports each named event in [events].
///
/// The browser reconnects by itself after a dropped connection; [onClosed]
/// is called only when it gives up (readyState 2, e.g. a 401 for an expired
/// platform token), so the caller can retry on its own terms.
BrowserSse? openBrowserSse(
  String url, {
  required List<String> events,
  required void Function(String event, String data) onEvent,
  required void Function() onOpen,
  required void Function() onClosed,
}) {
  final source = _EventSource(url);
  for (final name in events) {
    source.addEventListener(
      name,
      ((JSObject e) {
        final data = _MessageEvent(e).data;
        onEvent(name, data != null && data.isA<JSString>() ? (data as JSString).toDart : '');
      }).toJS,
    );
  }
  source.addEventListener('open', ((JSObject _) => onOpen()).toJS);
  source.addEventListener(
    'error',
    ((JSObject _) {
      if (source.readyState == 2) onClosed();
    }).toJS,
  );
  return _Sse(source);
}
