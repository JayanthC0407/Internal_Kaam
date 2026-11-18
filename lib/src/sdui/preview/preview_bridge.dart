// Messages between the DXP Studio (parent page) and the preview (iframe).
// Only the web build has a parent page; elsewhere these do nothing.
export 'preview_bridge_stub.dart'
    if (dart.library.js_interop) 'preview_bridge_web.dart';
