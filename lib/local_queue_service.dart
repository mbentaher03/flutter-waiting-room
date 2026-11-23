// lib/local_queue_service.dart
// Exports the web (in-memory) implementation when running in a browser,
// and the native (sqflite) implementation on all other platforms.
export 'local_queue_service_native.dart'
    if (dart.library.js_interop) 'local_queue_service_web.dart';
