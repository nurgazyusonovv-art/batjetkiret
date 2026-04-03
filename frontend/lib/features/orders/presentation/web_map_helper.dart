/// Conditional export: web implementation on web, stub on mobile/desktop.
export 'web_map_helper_stub.dart'
    if (dart.library.html) 'web_map_helper_web.dart';
