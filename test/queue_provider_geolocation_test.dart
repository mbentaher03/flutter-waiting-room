// test/queue_provider_geolocation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/geolocation_service.dart';
import 'package:flutter_application_1/local_queue_service.dart';
import 'package:flutter_application_1/queue_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'queue_provider_geolocation_test.mocks.dart';

@GenerateMocks([GeolocationService, SupabaseClient])
void main() {
  setUpAll(() {
    // Use in-memory database for tests
    databaseFactory = databaseFactoryFfi;
  });

  test('addClient saves client with geolocation', () async {
    final mockGeo = MockGeolocationService();
    final mockPos = Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => mockPos);

    // Use a mock SupabaseClient and in-memory local DB
    final mockSupabase = MockSupabaseClient();
    final localDb = LocalQueueService(inMemory: true);

    final provider = QueueProvider.forTesting(
      mockSupabase,
      localDb: localDb,
      geoService: mockGeo,
    );

    await provider.addClient('Test User');

    final client = provider.clients.last;
    expect(client['lat'], 37.7749);
    expect(client['lng'], -122.4194);
    expect(client['name'], 'Test User');

    verify(mockGeo.getCurrentPosition()).called(1);
  });

  test('addClient saves null location when geolocation fails', () async {
    final mockGeo = MockGeolocationService();
    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => null);

    final mockSupabase = MockSupabaseClient();
    final localDb = LocalQueueService(inMemory: true);

    final provider = QueueProvider.forTesting(
      mockSupabase,
      localDb: localDb,
      geoService: mockGeo,
    );

    await provider.addClient('No Location User');

    final client = provider.clients.last;
    expect(client['lat'], isNull);
    expect(client['lng'], isNull);
    expect(client['name'], 'No Location User');
  });
}
