import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/queue_provider.dart';
import 'package:flutter_application_1/services/sync_service.dart';
import 'support/queue_fakes.dart';

void main() {
  test('a blank name is rejected without creating a pending registration', () async {
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

    await provider.addClient('   ');

    expect(provider.pendingClients, isEmpty);
    expect(provider.errorMessage, isNotNull);
    provider.dispose();
    connectivity.dispose();
  });
}
