import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/queue_provider.dart';
import 'package:flutter_application_1/models/client.dart';
import 'package:flutter_application_1/models/app_connectivity.dart';
import 'package:flutter_application_1/models/sync_status.dart';
import 'package:flutter_application_1/services/sync_service.dart';
import '../support/queue_fakes.dart';

void main() {
  test('offline registration remains pending, without an official number', () async {
    final storage = MemoryQueueStorage();
    final repository = MemoryQueueRepository();
    final connectivity = makeTestConnectivity();
    final provider = QueueProvider(
      repository: repository,
      storage: storage,
      geolocation: FixedGeolocationService(),
      connectivity: connectivity,
      syncService: SyncService(storage, repository),
    );

    await provider.addClient('Offline guest');

    expect(provider.clients, isEmpty);
    expect(provider.pendingClients.single.queueNumber, isNull);
    expect(provider.pendingClients.single.name, 'Offline guest');
    provider.dispose();
    connectivity.dispose();
  });

  test('pagination loads later pages and Realtime inserts do not duplicate ids', () async {
    final storage = MemoryQueueStorage();
    final repository = MemoryQueueRepository();
    final now = DateTime.utc(2026);
    repository.official.addAll(List.generate(
      21,
      (index) => Client(
        id: 'client-$index',
        name: 'Client $index',
        createdAt: now.add(Duration(seconds: index)),
        queueNumber: index + 1,
        syncStatus: SyncStatus.synced,
      ),
    ));
    final online = makeTestConnectivity(initialStatus: AppConnectivity.online);
    final provider = QueueProvider(
      repository: repository,
      storage: storage,
      geolocation: FixedGeolocationService(),
      connectivity: online,
      syncService: SyncService(storage, repository),
    );

    await provider.fetchInitialQueue();
    expect(provider.clients, hasLength(20));
    expect(provider.hasMore, isTrue);
    await provider.loadMore();
    expect(provider.clients, hasLength(21));
    repository.emitInsert(repository.official.first);
    expect(provider.clients, hasLength(21));
    provider.dispose();
    online.dispose();
  });
}
