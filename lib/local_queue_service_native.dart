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
      return openDatabase(':memory:', version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
    }
    final path = join(await getDatabasesPath(), 'waiting_room.db');
    return openDatabase(path, version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
        location_accuracy_m REAL,
        location_captured_at TEXT,
        created_at TEXT NOT NULL,
        queue_number INTEGER,
        owner_id TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN location_accuracy_m REAL');
      await db.execute('ALTER TABLE $tableName ADD COLUMN location_captured_at TEXT');
      await db.execute("ALTER TABLE $tableName ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'pending'");
      await db.execute("UPDATE $tableName SET sync_status = 'synced' WHERE is_synced = 1");
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN queue_number INTEGER');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN owner_id TEXT');
    }
  }

  // ── Insert / replace ──────────────────────────────────────────────────────

  Future<void> insertClientLocally(Map<String, dynamic> client) async {
    final db = await database;
    final row = {
      'id': client['id'],
      'name': client['name'],
      'lat': client['lat'],
      'lng': client['lng'],
      'location_accuracy_m': client['location_accuracy_m'],
      'location_captured_at': client['location_captured_at'],
      'created_at': client['created_at'],
      'queue_number': client['queue_number'],
      'owner_id': client['owner_id'],
      'is_synced': client['is_synced'] ?? 0,
      'sync_status': client['sync_status'] ?? 'pending',
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
    await updateClientSyncStatus(id, 'synced');
  }

  Future<void> updateClientSyncStatus(String id, String status) async {
    final db = await database;
    await db.update(tableName, {
      'is_synced': status == 'synced' ? 1 : 0,
      'sync_status': status,
    },
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateClientQueueNumber(String id, int queueNumber) async {
    final db = await database;
    await db.update(tableName, {'queue_number': queueNumber},
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
