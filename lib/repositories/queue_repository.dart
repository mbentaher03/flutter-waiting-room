import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client.dart';

abstract interface class QueueRepository {
  Future<int> registerOnServer(Client client);
  Future<List<Client>> fetchPage({required int offset, required int limit});
  RealtimeChannel subscribe(void Function(Client client) onInsert,
      void Function(String id) onDelete);
  Future<void> unsubscribe(RealtimeChannel channel);
}

/// Supabase adapter. Location fields are written via RPC and never selected
/// when reading the public queue.
class SupabaseQueueRepository implements QueueRepository {
  final SupabaseClient _client;

  SupabaseQueueRepository(this._client);

  @override
  Future<int> registerOnServer(Client client) async {
    final result = await _client.rpc('register_queue_client', params: {
      // UUID values stay strings in Dart/JSON; the SQL RPC parameter is uuid.
      'p_id': client.id,
      'p_name': client.name,
      'p_lat': client.lat,
      'p_lng': client.lng,
      'p_accuracy': client.locationAccuracy,
      'p_location_captured_at': client.locationCapturedAt?.toIso8601String(),
      'p_created_at': client.createdAt.toIso8601String(),
    });
    if (result is num) return result.toInt();
    if (result is Map && result['register_queue_client'] is num) {
      return (result['register_queue_client'] as num).toInt();
    }
    throw const FormatException('Queue registration returned no queue number.');
  }

  @override
  Future<List<Client>> fetchPage({required int offset, required int limit}) async {
    final rows = await _client
        .from('clients')
        .select('id, name, created_at, queue_number')
        .order('queue_number', ascending: true)
        .range(offset, offset + limit - 1);
    return rows
        .map((row) => Client.fromSupabaseMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  RealtimeChannel subscribe(
    void Function(Client client) onInsert,
    void Function(String id) onDelete,
  ) {
    return _client
        .channel('waiting-room')
        // Broadcast events contain an explicit public-field allowlist. Direct
        // Postgres Changes could include private location columns in payloads.
        .onBroadcast(
          event: 'queue_insert',
          callback: (payload) {
            if (payload['id'] != null && payload['name'] != null) {
              onInsert(Client.fromSupabaseMap({
                'id': payload['id'],
                'name': payload['name'],
                'created_at': payload['created_at'],
                'queue_number': payload['queue_number'],
              }));
            }
          },
        )
        .onBroadcast(
          event: 'queue_delete',
          callback: (payload) {
            final id = payload['id'];
            if (id != null) onDelete(id.toString());
          },
        )
        .subscribe();
  }

  @override
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
