import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'local_queue_service.dart';
import 'geolocation_service.dart';

class QueueProvider extends ChangeNotifier {
  late final SupabaseClient _supabase;
  final LocalQueueService _localDb;
  final GeolocationService _geoService;
  late StreamSubscription<List<Map<String, dynamic>>> _subscription;

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> get clients => _clients;

  // Default constructor uses the live Supabase instance
  QueueProvider({
    LocalQueueService? localDb,
    GeolocationService? geoService,
  })  : _localDb = localDb ?? LocalQueueService(),
        _geoService = geoService ?? GeolocationService() {
    _supabase = Supabase.instance.client;
    initialize();
  }

  // Constructor for testing with a mock client
  QueueProvider.forTesting(
    this._supabase, {
    LocalQueueService? localDb,
    GeolocationService? geoService,
  })  : _localDb = localDb ?? LocalQueueService(),
        _geoService = geoService ?? GeolocationService();

  Future<void> initialize() async {
    await _loadQueue();
  }

  Future<void> _loadQueue() async {
    // 1. Load from local DB immediately (offline support)
    _clients = await _localDb.getClients();
    notifyListeners();

    // 2. Sync unsynced records to Supabase
    await _syncLocalToRemote();

    // 3. Subscribe to real-time updates
    _setupRealtimeSubscription();
  }

  Future<void> _syncLocalToRemote() async {
    final unsynced = await _localDb.getUnsyncedClients();
    for (var client in unsynced) {
      try {
        final remoteClient = Map<String, dynamic>.from(client)
          ..remove('is_synced');
        await _supabase.from('clients').upsert(remoteClient);
        await _localDb.markClientAsSynced(client['id'] as String);
      } catch (e) {
        // Log error but continue syncing other items
        print('Sync failed for ${client['id']}: $e');
        // In production: consider retry logic or user notification
      }
    }

    // Refresh UI if any sync succeeded
    _clients = await _localDb.getClients();
    notifyListeners();
  }

  Future<void> addClient(String name) async {
    if (name.trim().isEmpty) {
      print('Cannot add empty client name');
      return;
    }

    final position = await _geoService.getCurrentPosition();

    final newClient = {
      'id': const Uuid().v4(),
      'name': name.trim(),
      'lat': position?.latitude,
      'lng': position?.longitude,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    };

    // Save locally immediately
    await _localDb.insertClientLocally(newClient);

    // Update UI instantly
    _clients.add(newClient);
    _clients.sort((a, b) => a['created_at'].compareTo(b['created_at']));
    notifyListeners();

    // Attempt sync (non-blocking for UX)
    unawaited(_syncLocalToRemote());
  }

  void _setupRealtimeSubscription() {
    _subscription = _supabase
        .from('clients')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen((data) {
          _clients = List<Map<String, dynamic>>.from(data);
          notifyListeners();
        });
  }

  Future<void> removeClient(String id) async {
    try {
      await _supabase.from('clients').delete().match({'id': id});
      print('Client removed: $id');
    } catch (e) {
      print('Failed to remove client: $e');
    }
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) {
      print('Queue is empty!');
      return;
    }
    final firstClient = _clients.first;
    await removeClient(firstClient['id'] as String);
    print('Next client: ${firstClient['name']}');
  }

  @override
  void dispose() {
    _subscription.cancel();
    _localDb.close();
    super.dispose();
  }
}
