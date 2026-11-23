import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/models/client.dart';
import 'package:flutter_application_1/models/app_connectivity.dart';
import 'package:flutter_application_1/models/sync_status.dart';
import 'package:flutter_application_1/providers/connectivity_provider.dart';
import 'package:flutter_application_1/repositories/queue_repository.dart';
import 'package:flutter_application_1/services/connectivity_service.dart';
import 'package:flutter_application_1/services/geolocation_service.dart';
import 'package:flutter_application_1/storage/local_queue_storage.dart';

class MemoryQueueStorage implements QueueStorage {
  final Map<String, Client> rows = {};

  @override
  Future<void> saveClient(Client client) async {
    rows[client.id] = client;
  }

  @override
  Future<List<Client>> getPendingClients() async => rows.values
      .where((client) => client.syncStatus != SyncStatus.synced)
      .toList();

  @override
  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    rows[id] = rows[id]!.copyWith(syncStatus: status);
  }

  @override
  Future<void> updateQueueNumber(String id, int queueNumber) async {
    rows[id] = rows[id]!.copyWith(queueNumber: queueNumber);
  }

  @override
  Future<List<Client>> getAllClients() async => rows.values.toList();

  @override
  Future<void> deleteClient(String id) async {
    rows.remove(id);
  }

  @override
  Future<void> close() async {}
}

class MemoryQueueRepository implements QueueRepository {
  final SupabaseClient _client =
      SupabaseClient('https://example.supabase.co', 'test-anon-key');
  final List<Client> official = [];
  int registrations = 0;
  void Function(Client)? insertListener;
  void Function(String)? deleteListener;

  @override
  Future<int> registerOnServer(Client client) async {
    registrations++;
    final existing = official.indexWhere((item) => item.id == client.id);
    final queueNumber = existing < 0 ? official.length + 1 : official[existing].queueNumber!;
    final saved = client.copyWith(
      syncStatus: SyncStatus.synced,
      queueNumber: queueNumber,
    );
    if (existing < 0) official.add(saved); else official[existing] = saved;
    insertListener?.call(saved);
    return queueNumber;
  }

  @override
  Future<List<Client>> fetchPage({required int offset, required int limit}) async =>
      official.skip(offset).take(limit).toList();

  @override
  Future<void> deleteQueueClient(String id) async {
    official.removeWhere((client) => client.id == id);
    deleteListener?.call(id);
  }

  @override
  Future<String?> callNextClient() async {
    if (official.isEmpty) return null;
    official.sort((a, b) => a.queueNumber!.compareTo(b.queueNumber!));
    final id = official.removeAt(0).id;
    deleteListener?.call(id);
    return id;
  }

  @override
  RealtimeChannel subscribe(
    void Function(Client) onInsert,
    void Function(String) onDelete,
  ) {
    insertListener = onInsert;
    deleteListener = onDelete;
    return _client.channel('test-waiting-room');
  }

  @override
  Future<void> unsubscribe(RealtimeChannel channel) async {}

  void emitInsert(Client client) => insertListener?.call(client);
}

class FixedGeolocationService extends GeolocationService {
  final Position? position;
  FixedGeolocationService([this.position]);

  @override
  Future<Position?> getCurrentPosition() async => position;
}

ConnectivityProvider makeTestConnectivity({
  AppConnectivity initialStatus = AppConnectivity.checking,
}) => ConnectivityProvider(
      ConnectivityService(
        SupabaseClient('https://example.supabase.co', 'test-anon-key'),
      ),
      initialStatus: initialStatus,
    );
