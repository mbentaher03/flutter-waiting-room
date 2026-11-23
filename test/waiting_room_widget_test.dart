import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/queue_provider.dart';
import 'package:flutter_application_1/screens/queue_screen.dart';
import 'package:flutter_application_1/services/sync_service.dart';
import 'package:flutter_application_1/providers/connectivity_provider.dart';
import 'package:flutter_application_1/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/queue_fakes.dart';

void main() {
  testWidgets('offline registration appears separately from the official queue',
      (tester) async {
    final storage = MemoryQueueStorage();
    final repository = MemoryQueueRepository();
    final connectivity = makeTestConnectivity();
    final queue = QueueProvider(
      repository: repository,
      storage: storage,
      geolocation: FixedGeolocationService(),
      connectivity: connectivity,
      syncService: SyncService(storage, repository),
    );
    await queue.addClient('Alice');

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivity),
        ChangeNotifierProvider<QueueProvider>.value(value: queue),
        ChangeNotifierProvider<AuthProvider>.value(
          value: AuthProvider(
            SupabaseClient('https://example.supabase.co', 'test-anon-key'),
          ),
        ),
      ],
      child: const MaterialApp(home: QueueScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.textContaining('not in the official queue'), findsOneWidget);
    expect(find.text('The waiting queue is empty'), findsOneWidget);
    queue.dispose();
    connectivity.dispose();
  });
}
