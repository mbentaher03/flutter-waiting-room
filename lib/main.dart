import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/queue_provider.dart'; // Make sure this matches your pubspec.yaml name!

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => QueueProvider(),
      child: const WaitingRoomApp(),
    ),
  );
}

class WaitingRoomApp extends StatefulWidget {
  const WaitingRoomApp({super.key});

  @override
  State<WaitingRoomApp> createState() => _WaitingRoomAppState();
}

class _WaitingRoomAppState extends State<WaitingRoomApp> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waiting Room',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Waiting Room'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Input Field & Add Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Enter name',
                      ),
                      onSubmitted: (name) {
                        if (name.trim().isNotEmpty) {
                          context.read<QueueProvider>().addClient(name);
                          _controller.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final name = _controller.text;
                      if (name.trim().isNotEmpty) {
                        context.read<QueueProvider>().addClient(name);
                        _controller.clear();
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Queue List
              Expanded(
                child: Consumer<QueueProvider>(
                  builder: (context, provider, _) {
                    if (provider.clients.isEmpty) {
                      return const Center(
                        child: Text('No one in queue yet...'),
                      );
                    }

                    return ListView.builder(
                      itemCount: provider.clients.length,
                      itemBuilder: (context, index) {
                        final client = provider.clients[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(client.name),
                            subtitle: Text(
                              client.createdAt.toString().split('.')[0],
                              style: const TextStyle(
                                fontSize: 12, 
                                color: Colors.grey,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                context.read<QueueProvider>()
                                    .removeClient(client.id);
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              
              // Next Button
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<QueueProvider>().nextClient();
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Client'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}