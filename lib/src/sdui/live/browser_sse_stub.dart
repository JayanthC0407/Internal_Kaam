/// An open browser SSE connection.
abstract class BrowserSse {
  void close();
}

/// No browser here: the caller falls back to its own stream.
BrowserSse? openBrowserSse(
  String url, {
  required List<String> events,
  required void Function(String event, String data) onEvent,
  required void Function() onOpen,
  required void Function() onClosed,
}) =>
    null;
