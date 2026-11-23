import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/queue_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => QueueProvider(),
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

  void _addClient(BuildContext context) {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      context.read<QueueProvider>().addClient(name);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waiting Room',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Waiting Room'),
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            // Clear All button — only visible when queue is not empty
            Consumer<QueueProvider>(
              builder: (context, provider, _) {
                if (provider.clients.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'Clear all clients',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Clear All?'),
                        content: const Text(
                            'This will remove every client from the queue.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      context.read<QueueProvider>().clearAll();
                    }
                  },
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // ── Input row ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Enter client name',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _addClient(context),
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _addClient(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Error banner ───────────────────────────────────────────
              Consumer<QueueProvider>(
                builder: (context, provider, _) {
                  final msg = provider.addError ?? provider.syncError;
                  if (msg == null) return const SizedBox.shrink();
                  final isInputError = provider.addError != null;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isInputError ? Colors.red.shade50 : Colors.blue.shade50,
                      border: Border.all(
                        color: isInputError ? Colors.red.shade200 : Colors.blue.shade200,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isInputError ? Icons.error_outline : Icons.cloud_off,
                          color: isInputError ? Colors.red.shade700 : Colors.blue.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            msg,
                            style: TextStyle(
                              color: isInputError ? Colors.red.shade800 : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ── Queue count + loading indicator ───────────────────────
              Consumer<QueueProvider>(
                builder: (context, provider, _) => Row(
                  children: [
                    Text(
                      'Queue: ${provider.clients.length} client(s)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (provider.isLoading) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Queue list ─────────────────────────────────────────────
              Expanded(
                child: Consumer<QueueProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading && provider.clients.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.clients.isEmpty) {
                      return const Center(
                        child: Text(
                          'No one in queue yet…',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: provider.clients.length,
                      itemBuilder: (context, index) {
                        final client = provider.clients[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              client['name']?.toString() ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              client['lat'] == null || client['lng'] == null
                                  ? 'Location not captured'
                                  : 'Location: ${(client['lat'] as num).toStringAsFixed(4)}, ${(client['lng'] as num).toStringAsFixed(4)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              tooltip: 'Remove client',
                              onPressed: () => context
                                  .read<QueueProvider>()
                                  .removeClient(
                                      client['id'] as String),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Next Client button ─────────────────────────────────────
              const SizedBox(height: 12),
              Consumer<QueueProvider>(
                builder: (context, provider, _) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: provider.clients.isEmpty
                        ? null
                        : () =>
                            context.read<QueueProvider>().nextClient(),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next Client'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
