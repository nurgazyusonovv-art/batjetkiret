/// Conditional export: web implementation on web, stub on mobile/desktop.
export 'web_map_interop_stub.dart'
    if (dart.library.html) 'web_map_interop_web.dart';
