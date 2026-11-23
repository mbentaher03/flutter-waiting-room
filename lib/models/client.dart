// lib/models/client.dart
import 'sync_status.dart';

/// Represents a single entry in the waiting-room queue.
class Client {
  final String id;
  final String name;
  final double? lat;
  final double? lng;
  final double? locationAccuracy;
  final DateTime? locationCapturedAt;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final int? queueNumber;

  const Client({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.locationAccuracy,
    this.locationCapturedAt,
    required this.createdAt,
    this.syncStatus = SyncStatus.synced,
    this.queueNumber,
  });

  // ── Computed properties ──────────────────────────────────────────────────

  bool get hasLocation => lat != null && lng != null;

  String get locationText {
    if (!hasLocation) return 'Location not captured';
    return '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}';
  }

  bool get isPending => syncStatus == SyncStatus.pending;

  // ── Serialization ────────────────────────────────────────────────────────

  /// For Supabase INSERT — only business columns, no local metadata.
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'location_accuracy_m': locationAccuracy,
      'location_captured_at': locationCapturedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// For local SQLite — includes sync_status for offline tracking.
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'location_accuracy_m': locationAccuracy,
      'location_captured_at': locationCapturedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'queue_number': queueNumber,
      'sync_status': syncStatus.name,
    };
  }

  /// From a Supabase row — sync_status defaults to synced.
  factory Client.fromSupabaseMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'].toString(),
      name: map['name'] as String,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      locationAccuracy: (map['location_accuracy_m'] as num?)?.toDouble(),
      locationCapturedAt: DateTime.tryParse(map['location_captured_at']?.toString() ?? ''),
      createdAt: DateTime.parse(
        (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      ),
      syncStatus: SyncStatus.synced,
      queueNumber: (map['queue_number'] as num?)?.toInt(),
    );
  }

  /// From a local SQLite row — restores sync_status.
  factory Client.fromLocalMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String,
      name: map['name'] as String,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      locationAccuracy: (map['location_accuracy_m'] as num?)?.toDouble(),
      locationCapturedAt: DateTime.tryParse(map['location_captured_at']?.toString() ?? ''),
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == (map['sync_status'] as String?),
        orElse: () => SyncStatus.pending,
      ),
      queueNumber: (map['queue_number'] as num?)?.toInt(),
    );
  }

  Client copyWith({SyncStatus? syncStatus, int? queueNumber}) {
    return Client(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      locationAccuracy: locationAccuracy,
      locationCapturedAt: locationCapturedAt,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      queueNumber: queueNumber ?? this.queueNumber,
    );
  }

  @override
  String toString() => 'Client(id: $id, name: $name, status: $syncStatus)';
}
