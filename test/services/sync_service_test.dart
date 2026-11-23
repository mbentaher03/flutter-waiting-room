import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/models/client.dart';
import 'package:flutter_application_1/models/sync_status.dart';
import 'package:flutter_application_1/repositories/queue_repository.dart';
import 'package:flutter_application_1/services/sync_service.dart';
import 'package:flutter_application_1/storage/local_queue_storage.dart';

class _MemoryStorage implements QueueStorage {
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

class _CountingRepository implements QueueRepository {
  int registrations = 0;

  @override
  Future<int> registerOnServer(Client client) async {
    registrations++;
    return 7;
  }

  @override
  Future<List<Client>> fetchPage({required int offset, required int limit}) async => [];

  @override
  RealtimeChannel subscribe(
    void Function(Client) onInsert,
    void Function(String) onDelete,
  ) => throw UnimplementedError();

  @override
  Future<void> unsubscribe(RealtimeChannel channel) async {}
}

void main() {
  test('sync retries are idempotent locally and store server queue number', () async {
    final storage = _MemoryStorage();
    final repository = _CountingRepository();
    final now = DateTime.utc(2026);
    await storage.saveClient(Client(
      id: 'offline-uuid',
      name: 'Test client',
      createdAt: now,
      syncStatus: SyncStatus.pending,
    ));

    final sync = SyncService(storage, repository);
    await sync.synchronize();
    await sync.synchronize();

    expect(repository.registrations, 1);
    expect(storage.rows['offline-uuid']?.syncStatus, SyncStatus.synced);
    expect(storage.rows['offline-uuid']?.queueNumber, 7);
  });
}
