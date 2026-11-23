import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reports device network state separately from Supabase reachability.
class ConnectivityService {
  final Connectivity _connectivity;
  final SupabaseClient _supabase;

  ConnectivityService(this._supabase, {Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> hasNetwork() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((item) => item != ConnectivityResult.none);
  }

  Stream<bool> get networkChanges => _connectivity.onConnectivityChanged.map(
        (results) => results.any((item) => item != ConnectivityResult.none),
      );

  Future<bool> isSupabaseAvailable() async {
    try {
      await _supabase
          .from('clients')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }
}
