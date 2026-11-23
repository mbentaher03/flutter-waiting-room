import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/app_connectivity.dart';
import '../models/client.dart';
import '../models/queue_state.dart';
import '../models/sync_status.dart';
import '../services/geolocation_service.dart';
import '../services/sync_service.dart';
import '../storage/local_queue_storage.dart';
import 'connectivity_provider.dart';
import '../repositories/queue_repository.dart';

class QueueProvider extends ChangeNotifier {
  static const int pageSize = 20;

  final QueueRepository _repository;
  final QueueStorage _storage;
  final GeolocationService _geolocation;
  final ConnectivityProvider _connectivity;
  final SyncService _sync;
  final List<Client> _clients = [];
  QueueState _state = QueueState.initial;
  String? _errorMessage;
  int _page = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _disposed = false;
  RealtimeChannel? _channel;
  String? _activeUserId;

  QueueProvider({
    required QueueRepository repository,
    required QueueStorage storage,
    required GeolocationService geolocation,
    required ConnectivityProvider connectivity,
    required SyncService syncService,
  })  : _repository = repository,
        _storage = storage,
        _geolocation = geolocation,
        _connectivity = connectivity,
        _sync = syncService {
    _connectivity.addListener(_onConnectivityChanged);
  }

  /// Official registrations assigned a server queue number.
  List<Client> get clients => List.unmodifiable(
        _clients.where((client) => client.syncStatus == SyncStatus.synced),
      );
  /// Offline or retrying registrations are shown separately from the official queue.
  List<Client> get pendingClients => List.unmodifiable(
        _clients.where((client) =>
            client.syncStatus != SyncStatus.synced &&
            (_activeUserId == null || client.ownerId == _activeUserId)),
      );
  QueueState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  AppConnectivity get connectivity => _connectivity.status;

  void activateUser(String userId) {
    _activeUserId = userId;
    _clients.removeWhere((client) =>
        client.syncStatus != SyncStatus.synced && client.ownerId != userId);
    _notify();
  }

  void deactivateUser() {
    _activeUserId = null;
    _clients.removeWhere((client) => client.syncStatus != SyncStatus.synced);
    final channel = _channel;
    _channel = null;
    if (channel != null) unawaited(_repository.unsubscribe(channel));
    _notify();
  }

  Future<void> initialize() async {
    _state = QueueState.loading;
    _notify();
    try {
      _replaceClients(await _storage.getAllClients());
      _clients.removeWhere((client) =>
          client.syncStatus != SyncStatus.synced &&
          _activeUserId != null && client.ownerId != _activeUserId);
      if (_clients.isNotEmpty) _state = QueueState.loaded;
      _notify();
      if (_connectivity.status == AppConnectivity.online) {
        await _syncAndFetch();
        _startRealtime();
      } else {
        _state = _clients.isEmpty ? QueueState.empty : QueueState.loaded;
      }
    } catch (e) {
      _errorMessage = 'Could not load the saved queue.';
      _state = _clients.isEmpty ? QueueState.error : QueueState.loaded;
      debugPrint('Queue initialization failed: $e');
    }
    _notify();
  }

  Future<void> fetchInitialQueue({bool showRefreshing = false}) async {
    if (_connectivity.status != AppConnectivity.online) {
      _state = _clients.isEmpty ? QueueState.empty : QueueState.loaded;
      _notify();
      return;
    }
    _state = showRefreshing ? QueueState.refreshing : QueueState.loading;
    _errorMessage = null;
    _page = 0;
    _hasMore = true;
    _notify();
    try {
      final rows = await _repository.fetchPage(offset: 0, limit: pageSize);
      _replaceClients(_mergeServerWithLocal(rows));
      _hasMore = rows.length == pageSize;
      _state = _clients.isEmpty ? QueueState.empty : QueueState.loaded;
      _startRealtime();
    } catch (e) {
      debugPrint('Queue fetch failed: $e');
      _errorMessage = e is PostgrestException &&
              (e.code == '42703' || e.code == 'PGRST204' || e.code == 'PGRST202')
          ? 'Run the Workshop 6 Supabase migration, then retry.'
          : 'Could not load the queue from the server.';
      final local = await _storage.getAllClients();
      if (local.isNotEmpty) {
        _replaceClients(local);
        _state = QueueState.loaded;
      } else {
        _state = QueueState.error;
      }
    }
    _notify();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore ||
        _connectivity.status != AppConnectivity.online) return;
    _isLoadingMore = true;
    _state = QueueState.loadingMore;
    _notify();
    final nextPage = _page + 1;
    try {
      final rows = await _repository.fetchPage(
        offset: nextPage * pageSize,
        limit: pageSize,
      );
      final ids = _clients.map((client) => client.id).toSet();
      _clients.addAll(rows.where((client) => ids.add(client.id)));
      _page = nextPage;
      _hasMore = rows.length == pageSize;
      _sortClients();
    } catch (e) {
      debugPrint('Loading next queue page failed: $e');
      _errorMessage = 'Could not load more queue entries.';
    } finally {
      _isLoadingMore = false;
      _state = _clients.isEmpty ? QueueState.empty : QueueState.loaded;
      _notify();
    }
  }

  Future<void> addClient(String name, {String? ownerId}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Enter a name to join the queue.';
      _notify();
      return;
    }
    Position? position;
    try {
      position = await _geolocation.getCurrentPosition();
    } catch (e) {
      debugPrint('Optional geolocation failed: $e');
    }
    final now = DateTime.now().toUtc();
    final client = Client(
      id: const Uuid().v4(),
      name: trimmed,
      lat: position?.latitude,
      lng: position?.longitude,
      locationAccuracy: position?.accuracy,
      locationCapturedAt: position?.timestamp.toUtc(),
      createdAt: now,
      syncStatus: SyncStatus.pending,
      ownerId: ownerId ?? _activeUserId,
    );
    try {
      await _storage.saveClient(client);
      _upsert(client);
      _errorMessage = null;
      _state = QueueState.loaded;
      _notify();
      if (_connectivity.status == AppConnectivity.online) {
        await _syncAndFetch();
      }
    } catch (e) {
      _errorMessage = 'Could not save this registration on this device.';
      debugPrint('Local registration failed: $e');
      _notify();
    }
  }

  Future<void> refresh() => fetchInitialQueue(showRefreshing: true);

  Future<void> adminDeleteClient(String id) async {
    try {
      await _repository.deleteQueueClient(id);
      _onRealtimeDelete(id);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Could not remove this client. Check admin access and retry.';
      debugPrint('Admin queue deletion failed: $e');
      _notify();
      rethrow;
    }
  }

  Future<String?> adminCallNextClient() async {
    try {
      final id = await _repository.callNextClient();
      if (id != null) _onRealtimeDelete(id);
      _errorMessage = null;
      return id;
    } catch (e) {
      _errorMessage = 'Could not call the next client. Check admin access and retry.';
      debugPrint('Admin call-next failed: $e');
      _notify();
      rethrow;
    }
  }

  Future<void> _syncAndFetch() async {
    final userId = _activeUserId;
    if (userId == null) return;
    final assignedNumbers = await _sync.synchronize(userId: userId);
    for (var i = 0; i < _clients.length; i++) {
      final number = assignedNumbers[_clients[i].id];
      if (number != null) {
        _clients[i] = _clients[i].copyWith(
          queueNumber: number,
          syncStatus: SyncStatus.synced,
        );
      }
    }
    await fetchInitialQueue(showRefreshing: _clients.isNotEmpty);
  }

  List<Client> _mergeServerWithLocal(List<Client> serverRows) {
    final localById = {for (final client in _clients) client.id: client};
    return [
      for (final server in serverRows)
        server.copyWith(
          syncStatus: SyncStatus.synced,
          // Coordinates remain private to the registering device. The public
          // queue fetch intentionally never selects the location columns.
        ),
      ..._clients.where((client) =>
          client.syncStatus != SyncStatus.synced &&
          (_activeUserId == null || client.ownerId == _activeUserId)),
    ].map((server) {
      final local = localById[server.id];
      if (local == null || server.syncStatus != SyncStatus.synced) return server;
      return Client(
        id: server.id,
        name: server.name,
        createdAt: server.createdAt,
        queueNumber: server.queueNumber,
        syncStatus: server.syncStatus,
        lat: local.lat,
        lng: local.lng,
        locationAccuracy: local.locationAccuracy,
        locationCapturedAt: local.locationCapturedAt,
      );
    }).toList();
  }

  void _replaceClients(Iterable<Client> clients) {
    _clients
      ..clear()
      ..addAll(clients);
    _sortClients();
  }

  void _upsert(Client client) {
    final index = _clients.indexWhere((item) => item.id == client.id);
    if (index == -1) {
      _clients.add(client);
    } else {
      _clients[index] = client;
    }
    _sortClients();
  }

  void _sortClients() => _clients.sort((a, b) {
        if (a.queueNumber != null && b.queueNumber != null) {
          return a.queueNumber!.compareTo(b.queueNumber!);
        }
        return a.createdAt.compareTo(b.createdAt);
      });

  void _onRealtimeInsert(Client client) {
    Client? current;
    for (final item in _clients) {
      if (item.id == client.id) {
        current = item;
        break;
      }
    }
    _upsert(current == null
        ? client
        : Client(
            id: client.id,
            name: client.name,
            createdAt: client.createdAt,
            queueNumber: client.queueNumber,
            syncStatus: SyncStatus.synced,
            lat: current.lat,
            lng: current.lng,
            locationAccuracy: current.locationAccuracy,
            locationCapturedAt: current.locationCapturedAt,
          ));
    if (_state == QueueState.empty) _state = QueueState.loaded;
    _notify();
  }

  void _onRealtimeDelete(String id) {
    _clients.removeWhere((client) => client.id == id);
    unawaited(_storage.deleteClient(id).catchError((Object e) {
      debugPrint('Could not remove deleted registration $id locally: $e');
    }));
    if (_clients.isEmpty) _state = QueueState.empty;
    _notify();
  }

  void _startRealtime() {
    if (_channel != null || _connectivity.status != AppConnectivity.online) return;
    _channel = _repository.subscribe(_onRealtimeInsert, _onRealtimeDelete);
  }

  void _onConnectivityChanged() {
    if (_connectivity.status == AppConnectivity.online &&
        _activeUserId != null) {
      unawaited(_syncAndFetch().then((_) => _startRealtime()).catchError((Object e) {
        _errorMessage = 'Could not synchronize the queue yet.';
        debugPrint('Connectivity recovery sync failed: $e');
        _notify();
      }));
    } else if (_connectivity.status == AppConnectivity.offline ||
        _connectivity.status == AppConnectivity.backendUnavailable) {
      final channel = _channel;
      _channel = null;
      if (channel != null) unawaited(_repository.unsubscribe(channel));
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivity.removeListener(_onConnectivityChanged);
    final channel = _channel;
    if (channel != null) unawaited(_repository.unsubscribe(channel));
    unawaited(_storage.close());
    super.dispose();
  }
}
