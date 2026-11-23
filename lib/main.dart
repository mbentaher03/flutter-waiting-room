import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/connectivity_provider.dart';
import 'providers/auth_provider.dart';
import 'queue_provider.dart';
import 'repositories/queue_repository.dart';
import 'screens/account_gate.dart';
import 'services/connectivity_service.dart';
import 'services/geolocation_service.dart';
import 'services/sync_service.dart';
import 'storage/local_queue_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final supabase = Supabase.instance.client;
  final storage = LocalQueueStorage();
  final repository = SupabaseQueueRepository(supabase);
  final connectivity =
      ConnectivityProvider(ConnectivityService(supabase));
  final auth = AuthProvider(supabase);
  final queue = QueueProvider(
    repository: repository,
    storage: storage,
    geolocation: GeolocationService(),
    connectivity: connectivity,
    syncService: SyncService(storage, repository),
  );
  unawaited(auth.initialize());

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: connectivity),
      ChangeNotifierProvider.value(value: queue),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: const WaitingRoomApp(),
  ));
}

class WaitingRoomApp extends StatelessWidget {
  const WaitingRoomApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Waiting Room',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AccountGate(),
      );
}
