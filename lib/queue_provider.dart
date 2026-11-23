import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'geolocation_service.dart';
import 'local_queue_service.dart';

/// Coordinates the local queue and the remote `clients` table.
/// Local writes always happen first; Supabase failures leave work queued.
class QueueProvider extends ChangeNotifier {
  final SupabaseClient? _supabase;
  final LocalQueueService _localDb;
  final GeolocationService _geoService;

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> get clients => List.unmodifiable(_clients);
  String? _syncError;
  String? get syncError => _syncError;
  String? _addError;
  String? get addError => _addError;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _disposed = false;
  Future<void>? _syncTask;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  QueueProvider({
    LocalQueueService? localDb,
    GeolocationService? geoService,
  })  : _supabase = Supabase.instance.client,
        _localDb = localDb ?? LocalQueueService(),
        _geoService = geoService ?? GeolocationService() {
    unawaited(initialize());
  }

  QueueProvider.forTesting(
    SupabaseClient supabase, {
    LocalQueueService? localDb,
    GeolocationService? geoService,
  })  : _supabase = supabase,
        _localDb = localDb ?? LocalQueueService(),
        _geoService = geoService ?? GeolocationService();

  Future<void> initialize() async {
    _isLoading = true;
    _notify();
    _connectivitySubscription ??= Connectivity()
        .onConnectivityChanged
        .listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(syncNow());
      }
    });
    try {
      _clients = await _localDb.getClients();
      _sortClients();
      _notify();
      await syncNow();
    } catch (e) {
      _syncError = 'Local queue could not be loaded: $e';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> addClient(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _addError = 'Name cannot be empty.';
      _notify();
      return;
    }

    _addError = null;
    Position? position;
    try {
      position = await _geoService.getCurrentPosition();
    } catch (e) {
      // Geolocation is optional. A plugin or browser permission error must
      // not block saving the client locally.
      debugPrint('Could not capture location: $e');
    }
    final row = <String, dynamic>{
      'id': const Uuid().v4(),
      'name': trimmed,
      'lat': position?.latitude,
      'lng': position?.longitude,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'is_synced': 0,
    };

    try {
      await _localDb.insertClientLocally(row);
      _clients.add(row);
      _sortClients();
      _notify();
      unawaited(syncNow());
    } catch (e) {
      _addError = 'Could not save the client locally: $e';
      _notify();
    }
  }

  /// Uploads pending rows and refreshes from Supabase. The location migration
  /// adds nullable lat/lng columns without changing existing records.
  Future<void> syncNow() {
    return _syncTask ??= _performSync().whenComplete(() => _syncTask = null);
  }

  Future<void> _performSync() async {
    final client = _supabase;
    if (client == null) return;
    var serverAvailable = false;
    String? schemaNotice;
    try {
      final pending = await _localDb.getUnsyncedClients();
      for (final row in pending) {
        try {
          await client.from('clients').upsert({
            'id': row['id'],
            'name': row['name'],
            'lat': row['lat'],
            'lng': row['lng'],
            'created_at': row['created_at'],
          });
          await _localDb.markClientAsSynced(row['id'].toString());
        } catch (e) {
          if (_missingLocationColumns(e)) {
            // Older Supabase schemas can still receive the queue entry. Keep
            // coordinates in local storage until the optional columns exist.
            try {
              await client.from('clients').upsert({
                'id': row['id'],
                'name': row['name'],
                'created_at': row['created_at'],
              });
              schemaNotice =
                  'Client synced. Location remains on this device until Supabase has lat and lng columns.';
              continue;
            } catch (fallbackError) {
              debugPrint('Queue sync failed for ${row['id']}: $fallbackError');
            }
          } else {
            debugPrint('Queue sync failed for ${row['id']}: $e');
          }
          _syncError =
              'Saved on this device. Sync will retry when the server is available.';
          break;
        }
      }

      final remote = await client
          .from('clients')
          .select('id, name, created_at')
          .order('created_at', ascending: true);
      serverAvailable = true;
      final local = await _localDb.getClients();
      final localById = <String, Map<String, dynamic>>{
        for (final row in local) row['id'].toString(): row,
      };
      final localPending = local.where((r) => r['is_synced'] != 1);
      final byId = <String, Map<String, dynamic>>{
        for (final raw in remote)
          raw['id'].toString(): _normalizeRowWithLocalLocation(
            raw as Map<String, dynamic>,
            localById[raw['id'].toString()],
          ),
        for (final row in localPending) row['id'].toString(): row,
      };
      _clients = byId.values.toList();
      _sortClients();
      _syncError = schemaNotice;
    } catch (e) {
      // Keep the last locally loaded queue visible when offline.
      if (!serverAvailable) {
        debugPrint('Could not refresh queue from Supabase: $e');
        _syncError = 'Offline: changes are saved on this device and will sync when connected.';
      }
    }
    _notify();
  }

  Future<void> removeClient(String id) async {
    final existing = _clients.where((c) => c['id']?.toString() == id).toList();
    if (existing.isEmpty) return;
    _clients.removeWhere((c) => c['id']?.toString() == id);
    await _localDb.deleteClientLocally(id);
    _notify();
    try {
      await _supabase?.from('clients').delete().eq('id', id);
      _syncError = null;
    } catch (e) {
      debugPrint('Could not delete client $id from Supabase: $e');
      _syncError = 'Could not reach the server. The deletion may need retrying.';
    }
    _notify();
  }

  Future<void> nextClient() async {
    if (_clients.isNotEmpty) {
      await removeClient(_clients.first['id'].toString());
    }
  }

  Future<void> clearAll() async {
    final ids = _clients.map((c) => c['id'].toString()).toList();
    _clients.clear();
    await _localDb.deleteAllClients();
    _notify();
    for (final id in ids) {
      try {
        await _supabase?.from('clients').delete().eq('id', id);
      } catch (e) {
        _syncError = 'Some server records could not be deleted: $e';
      }
    }
    _notify();
  }

  Map<String, dynamic> _normalizeRow(Map<String, dynamic> row) => {
        'id': row['id']?.toString() ?? '',
        'name': row['name']?.toString() ?? '',
        'lat': (row['lat'] as num?)?.toDouble(),
        'lng': (row['lng'] as num?)?.toDouble(),
        'created_at': row['created_at']?.toString() ??
            DateTime.now().toUtc().toIso8601String(),
        'is_synced': 1,
      };

  Map<String, dynamic> _normalizeRowWithLocalLocation(
    Map<String, dynamic> row,
    Map<String, dynamic>? local,
  ) => {
        ..._normalizeRow(row),
        'lat': row['lat'] ?? local?['lat'],
        'lng': row['lng'] ?? local?['lng'],
      };

  bool _missingLocationColumns(Object error) {
    if (error is! PostgrestException) return false;
    return error.code == '42703' || error.code == 'PGRST204';
  }

  void _sortClients() => _clients.sort((a, b) =>
      (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? ''));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_localDb.close());
    super.dispose();
  }
}
