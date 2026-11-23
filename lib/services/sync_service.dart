import '../models/client.dart';
import '../models/sync_status.dart';
import '../repositories/queue_repository.dart';
import '../storage/local_queue_storage.dart';

class SyncService {
  final QueueStorage _storage;
  final QueueRepository _repository;
  bool _isSyncing = false;

  SyncService(this._storage, this._repository);

  Future<Map<String, int>> synchronize() async {
    if (_isSyncing) return const {};
    final numbers = <String, int>{};
    _isSyncing = true;
    try {
      for (final pending in await _storage.getPendingClients()) {
        try {
          await _storage.updateSyncStatus(pending.id, SyncStatus.syncing);
          final queueNumber = await _repository.registerOnServer(pending);
          await _storage.updateQueueNumber(pending.id, queueNumber);
          await _storage.updateSyncStatus(pending.id, SyncStatus.synced);
          numbers[pending.id] = queueNumber;
        } catch (_) {
          await _storage.updateSyncStatus(pending.id, SyncStatus.failed);
        }
      }
    } finally {
      _isSyncing = false;
    }
    return numbers;
  }
}
