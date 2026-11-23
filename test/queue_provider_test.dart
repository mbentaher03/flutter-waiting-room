import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/queue_state.dart';
import 'package:flutter_application_1/queue_provider.dart';
import 'package:flutter_application_1/services/sync_service.dart';
import 'support/queue_fakes.dart';

void main() {
  test('provider begins in its initial state', () {
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

    expect(provider.state, QueueState.initial);
    expect(provider.clients, isEmpty);
    provider.dispose();
    connectivity.dispose();
  });
}
