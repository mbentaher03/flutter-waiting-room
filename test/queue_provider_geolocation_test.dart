import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_application_1/models/sync_status.dart';
import 'package:flutter_application_1/queue_provider.dart';
import 'package:flutter_application_1/services/sync_service.dart';
import 'support/queue_fakes.dart';

void main() {
  test('registration stores optional coordinates and accuracy locally', () async {
    final position = Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.utc(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    final storage = MemoryQueueStorage();
    final repository = MemoryQueueRepository();
    final connectivity = makeTestConnectivity();
    final provider = QueueProvider(
      repository: repository,
      storage: storage,
      geolocation: FixedGeolocationService(position),
      connectivity: connectivity,
      syncService: SyncService(storage, repository),
    );

    await provider.addClient('Test User');

    final client = provider.pendingClients.single;
    expect(client.lat, 37.7749);
    expect(client.lng, -122.4194);
    expect(client.locationAccuracy, 5);
    expect(client.syncStatus, SyncStatus.pending);
    expect(provider.clients, isEmpty);
    provider.dispose();
    connectivity.dispose();
  });

  test('registration succeeds when location permission is unavailable', () async {
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

    await provider.addClient('No GPS User');

    expect(provider.pendingClients.single.name, 'No GPS User');
    expect(provider.pendingClients.single.hasLocation, isFalse);
    provider.dispose();
    connectivity.dispose();
  });
}
