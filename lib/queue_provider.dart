import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/models/client.dart';

class QueueProvider extends ChangeNotifier {
  final List<Client> _clients = [];
  List<Client> get clients => _clients;

  late final SupabaseClient _supabase;
  late StreamSubscription<List<Map<String, dynamic>>> _subscription;

  // Default constructor uses the live Supabase instance
  QueueProvider() {
    _supabase = Supabase.instance.client;
    _fetchInitialClients();
    _setupRealtimeSubscription();
  }

  // Constructor for testing with a mock client
  QueueProvider.forTesting(this._supabase) {
    _fetchInitialClients();
    _setupRealtimeSubscription();
  }
  
  // ... rest of your methods stay the same

  Future<void> _fetchInitialClients() async {
    try {
      final response = await _supabase
          .from('clients')
          .select()
          .order('created_at', ascending: true);

      _clients.clear();
      _clients.addAll((response as List).map((map) => Client.fromMap(map)));
      notifyListeners();
    } catch (e) {
      print('Error fetching clients: $e');
    }
  }

  void _setupRealtimeSubscription() {
    // Using modern Supabase stream syntax for real-time sync
    _subscription = _supabase
        .from('clients')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen((data) {
          _clients.clear();
          _clients.addAll(data.map((map) => Client.fromMap(map)));
          notifyListeners();
        });
  }

  Future<void> addClient(String name) async {
    if (name.trim().isEmpty) {
      print('Cannot add empty client name');
      return;
    }
    try {
      await _supabase.from('clients').insert({'name': name.trim()});
      print('Client added: $name');
    } catch (e) {
      print('Failed to add client: $e');
    }
  }

  Future<void> removeClient(String id) async {
    try {
      await _supabase.from('clients').delete().match({'id': id});
      print('Client removed: $id');
    } catch (e) {
      print('Failed to remove client: $e');
    }
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) {
      print('Queue is empty!');
      return;
    }
    final firstClient = _clients.first;
    await removeClient(firstClient.id);
    print('Next client: ${firstClient.name}');
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}