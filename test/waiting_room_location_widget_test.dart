// test/waiting_room_location_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/queue_provider.dart';

import 'waiting_room_location_widget_test.mocks.dart';

@GenerateMocks([QueueProvider])
void main() {
  testWidgets('Displays location when available', (tester) async {
    final provider = MockQueueProvider();

    when(provider.clients).thenReturn([
      {
        'id': '1',
        'name': 'Sam',
        'lat': 51.5074,
        'lng': -0.1278,
        'created_at': DateTime.now().toIso8601String(),
      }
    ]);

    // MockQueueProvider needs to behave like a ChangeNotifier
    when(provider.addListener(any)).thenReturn(null);
    when(provider.removeListener(any)).thenReturn(null);
    when(provider.hasListeners).thenReturn(false);

    await tester.pumpWidget(
      ChangeNotifierProvider<QueueProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer<QueueProvider>(
              builder: (context, provider, _) {
                final clients = provider.clients;
                return ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return ListTile(
                      title: Text(client['name'] ?? ''),
                      subtitle: Text(
                        client['lat'] == null
                            ? '📍 Location not captured'
                            : '📍 ${client['lat']?.toStringAsFixed(4)}, ${client['lng']?.toStringAsFixed(4)}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sam'), findsOneWidget);
    expect(find.textContaining('51.5074'), findsOneWidget);
    expect(find.textContaining('-0.1278'), findsOneWidget);
  });

  testWidgets('Shows "Location not captured" when lat is null', (tester) async {
    final provider = MockQueueProvider();

    when(provider.clients).thenReturn([
      {
        'id': '2',
        'name': 'Alex',
        'lat': null,
        'lng': null,
        'created_at': DateTime.now().toIso8601String(),
      }
    ]);

    when(provider.addListener(any)).thenReturn(null);
    when(provider.removeListener(any)).thenReturn(null);
    when(provider.hasListeners).thenReturn(false);

    await tester.pumpWidget(
      ChangeNotifierProvider<QueueProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer<QueueProvider>(
              builder: (context, provider, _) {
                final clients = provider.clients;
                return ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return ListTile(
                      title: Text(client['name'] ?? ''),
                      subtitle: Text(
                        client['lat'] == null
                            ? '📍 Location not captured'
                            : '📍 ${client['lat']?.toStringAsFixed(4)}, ${client['lng']?.toStringAsFixed(4)}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('📍 Location not captured'), findsOneWidget);
  });
}
