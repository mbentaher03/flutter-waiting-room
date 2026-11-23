export 'database_factory_initializer_stub.dart'
    if (dart.library.io) 'database_factory_initializer_native.dart'
    if (dart.library.js_interop) 'database_factory_initializer_web.dart';
