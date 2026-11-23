// lib/models/sync_status.dart
/// Tracks whether a locally-created client has been persisted to Supabase.
enum SyncStatus {
  pending,   // saved locally only, not yet sent to Supabase
  syncing,   // upload in progress
  synced,    // confirmed in Supabase
  failed,    // upload attempted but failed
}
