// lib/local_queue_service_web.dart
// Web uses browser localStorage so offline entries survive reloads. This avoids
// sqflite_common_ffi_web's separately-served worker script.

import 'dart:convert';
import 'dart:html' as html;

class LocalQueueService {
  static const _storageKey = 'waiting_room.local_clients.v1';
  final bool _inMemory;
  final List<Map<String, dynamic>> _memoryStore = [];

  LocalQueueService({bool inMemory = false}) : _inMemory = inMemory;

  List<Map<String, dynamic>> get _store {
    if (_inMemory) return _memoryStore;
    try {
      final json = html.window.localStorage[_storageKey];
      if (json == null) return [];
      return (jsonDecode(json) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save(List<Map<String, dynamic>> rows) {
    if (_inMemory) return;
    html.window.localStorage[_storageKey] = jsonEncode(rows);
  }

  // ── Insert / replace ──────────────────────────────────────────────────────

  Future<void> insertClientLocally(Map<String, dynamic> client) async {
    final id = client['id'] as String;
    final rows = _store..removeWhere((c) => c['id'] == id);
    rows.add(Map<String, dynamic>.from(client));
    _save(rows);
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getClients() async {
    final list = _store.map((c) => Map<String, dynamic>.from(c)).toList();
    list.sort((a, b) => (a['created_at']?.toString() ?? '')
        .compareTo(b['created_at']?.toString() ?? ''));
    return list;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedClients() async {
    return _store
        .where((c) => (c['is_synced'] as int?) != 1)
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
  }

  // ── Updates ───────────────────────────────────────────────────────────────

  Future<void> markClientAsSynced(String id) async {
    final rows = _store;
    final idx = rows.indexWhere((c) => c['id'] == id);
    if (idx != -1) rows[idx]['is_synced'] = 1;
    _save(rows);
  }

  // ── Deletes ───────────────────────────────────────────────────────────────

  Future<void> deleteClientLocally(String id) async {
    final rows = _store..removeWhere((c) => c['id'] == id);
    _save(rows);
  }

  Future<void> deleteAllClients() async {
    _save([]);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> close() async {
    // Nothing to close for in-memory store
  }
}
