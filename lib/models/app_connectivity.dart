// lib/models/app_connectivity.dart
/// Represents the current connectivity state of the application.
enum AppConnectivity {
  checking,            // initial / transitioning state
  online,              // device has network AND Supabase responds
  offline,             // device has no network connection
  backendUnavailable,  // device has network but Supabase is unreachable
}
