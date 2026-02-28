export 'analytics_manager_stub.dart'
    if (dart.library.io) 'analytics_manager_mobile.dart'
    if (dart.library.js) 'analytics_manager_web.dart';
