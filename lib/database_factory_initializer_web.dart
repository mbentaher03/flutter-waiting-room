import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> initializeDatabaseFactory({
  required bool isWeb,
  required TargetPlatform platform,
}) async {
  if (isWeb) databaseFactory = databaseFactoryFfiWeb;
}
