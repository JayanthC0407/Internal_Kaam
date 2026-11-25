// Server-Sent Events in a browser, through its own EventSource. Only the web
// build has one; elsewhere [openBrowserSse] returns null and the runtime uses
// its Dio stream instead.
export 'browser_sse_stub.dart' if (dart.library.js_interop) 'browser_sse_web.dart';
