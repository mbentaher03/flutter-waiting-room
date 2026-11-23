import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/client.dart';
import 'package:flutter_application_1/models/sync_status.dart';

void main() {
  group('Client', () {
    test('location is optional and formatted without exposing it by default', () {
      final client = Client(
        id: 'client-1',
        name: 'Amina',
        createdAt: DateTime.utc(2026),
      );
      expect(client.hasLocation, isFalse);
      expect(client.locationText, 'Location not captured');
    });

    test('local serialization retains location and sync status', () {
      final client = Client(
        id: 'client-2',
        name: 'Sami',
        lat: 36.8065,
        lng: 10.1815,
        locationAccuracy: 4.5,
        locationCapturedAt: DateTime.utc(2026, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1),
        syncStatus: SyncStatus.pending,
      );
      final restored = Client.fromLocalMap(client.toLocalMap());
      expect(restored.locationAccuracy, 4.5);
      expect(restored.syncStatus, SyncStatus.pending);
      expect(restored.hasLocation, isTrue);
    });

    test('remote payload excludes local sync metadata and queue location reads', () {
      final client = Client(
        id: 'client-3',
        name: 'Nour',
        createdAt: DateTime.utc(2026),
        syncStatus: SyncStatus.pending,
      );
      expect(client.toSupabaseMap().containsKey('sync_status'), isFalse);
    });
  });
}
