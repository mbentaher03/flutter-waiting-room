// lib/local_queue_service_native.dart
// Native (Android / iOS / Windows / Linux / macOS): sqflite-backed store.

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_factory_initializer.dart';

class LocalQueueService {
  Database? _database;
  static Future<void>? _factoryInitialization;
  static const String tableName = 'local_clients';
  final bool _inMemory;

  LocalQueueService({bool inMemory = false}) : _inMemory = inMemory;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    await _initializeDatabaseFactory();
    if (_inMemory) {
      return openDatabase(':memory:', version: 1, onCreate: _onCreate);
    }
    final path = join(await getDatabasesPath(), 'waiting_room.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _initializeDatabaseFactory() {
    return _factoryInitialization ??= initializeDatabaseFactory(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lat REAL,
        lng REAL,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ── Insert / replace ──────────────────────────────────────────────────────

  Future<void> insertClientLocally(Map<String, dynamic> client) async {
    final db = await database;
    final row = {
      'id': client['id'],
      'name': client['name'],
      'lat': client['lat'],
      'lng': client['lng'],
      'created_at': client['created_at'],
      'is_synced': client['is_synced'] ?? 0,
    };
    await db.insert(tableName, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getClients() async {
    final db = await database;
    return db.query(tableName, orderBy: 'created_at ASC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedClients() async {
    final db = await database;
    return db.query(tableName, where: 'is_synced = ?', whereArgs: [0]);
  }

  // ── Updates ───────────────────────────────────────────────────────────────

  Future<void> markClientAsSynced(String id) async {
    final db = await database;
    await db.update(tableName, {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // ── Deletes ───────────────────────────────────────────────────────────────

  Future<void> deleteClientLocally(String id) async {
    final db = await database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllClients() async {
    final db = await database;
    await db.delete(tableName);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
