import '../local_queue_service.dart';
import '../models/client.dart';
import '../models/sync_status.dart';

abstract interface class QueueStorage {
  Future<void> saveClient(Client client);
  Future<List<Client>> getPendingClients();
  Future<void> updateSyncStatus(String id, SyncStatus status);
  Future<void> updateQueueNumber(String id, int queueNumber);
  Future<List<Client>> getAllClients();
  Future<void> deleteClient(String id);
  Future<void> close();
}

class LocalQueueStorage implements QueueStorage {
  final LocalQueueService _service;

  LocalQueueStorage({LocalQueueService? service})
      : _service = service ?? LocalQueueService();

  @override
  Future<void> saveClient(Client client) =>
      _service.insertClientLocally(client.toLocalMap());

  @override
  Future<List<Client>> getPendingClients() async =>
      (await _service.getUnsyncedClients())
          .map((row) => Client.fromLocalMap(_withStatus(row, SyncStatus.pending)))
          .toList();

  @override
  Future<void> updateSyncStatus(String id, SyncStatus status) =>
      _service.updateClientSyncStatus(id, status.name);

  @override
  Future<void> updateQueueNumber(String id, int queueNumber) =>
      _service.updateClientQueueNumber(id, queueNumber);

  @override
  Future<List<Client>> getAllClients() async =>
      (await _service.getClients())
          .map((row) => Client.fromLocalMap(_withStatus(
                row,
                row['is_synced'] == 1 ? SyncStatus.synced : SyncStatus.pending,
              )))
          .toList();

  @override
  Future<void> deleteClient(String id) => _service.deleteClientLocally(id);

  Map<String, dynamic> _withStatus(
    Map<String, dynamic> row,
    SyncStatus status,
  ) => {
        ...row,
        'sync_status': row['sync_status'] ?? status.name,
        'created_at': row['created_at']?.toString() ??
            DateTime.now().toUtc().toIso8601String(),
      };

  @override
  Future<void> close() => _service.close();
}
