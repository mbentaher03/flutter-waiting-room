import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  static const _authDomain = 'waiting-room.invalid';
  final SupabaseClient _client;
  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _busy = false;
  bool _emailConfirmationRequired = false;
  String? _error;
  bool _disposed = false;

  AuthProvider(this._client);

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _loading;
  bool get isBusy => _busy;
  bool get emailConfirmationRequired => _emailConfirmationRequired;
  String? get error => _error;
  bool get isApproved => _profile?['approved'] == true;
  bool get isAdmin => isApproved && _profile?['role'] == 'admin';
  bool get isRejected => _profile?['rejected'] == true;

  Future<void> initialize() async {
    _authSubscription = _client.auth.onAuthStateChange.listen((event) {
      unawaited(_loadUser(event.session?.user));
    });
    await _loadUser(_client.auth.currentUser);
  }

  Future<void> signIn(String username, String password) async {
    await _run(() async {
      final response = await _client.auth.signInWithPassword(
        email: _authEmail(username),
        password: password,
      );
      await _loadUser(response.user);
    });
  }

  Future<void> signUp(String username, String password) async {
    await _run(() async {
      final response = await _client.auth.signUp(
        email: _authEmail(username),
        password: password,
      );
      _emailConfirmationRequired = response.session == null;
      if (response.user != null && response.session != null) {
        await _loadUser(response.user);
      }
    });
  }

  Future<void> signOut() async {
    await _run(() async {
      await _client.auth.signOut();
      await _loadUser(null);
    });
  }

  Future<List<Map<String, dynamic>>> loadPendingApprovals() async {
    if (!isAdmin) throw StateError('Administrator access required.');
    final rows = await _client
        .from('profiles')
        .select('id, username, created_at')
        .eq('approved', false)
        .eq('rejected', false)
        .order('created_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> decideApproval(String userId, {required bool approve}) async {
    if (!isAdmin) throw StateError('Administrator access required.');
    await _client.rpc('admin_set_user_approval', params: {
      'p_user_id': userId,
      'p_approved': approve,
    });
  }

  Future<List<Map<String, dynamic>>> loadApprovedUsers() async {
    if (!isAdmin) throw StateError('Administrator access required.');
    final rows = await _client
        .from('profiles')
        .select('id, username, role, created_at')
        .eq('approved', true)
        .order('username');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> changeUserRole(String userId, String role) async {
    if (!isAdmin) throw StateError('Administrator access required.');
    await _client.rpc('admin_set_user_role', params: {
      'p_user_id': userId,
      'p_role': role,
    });
  }

  Future<void> refreshProfile() => _loadUser(_user);

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _emailConfirmationRequired = false;
    _notify();
    try {
      await action();
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _loadUser(User? user) async {
    _user = user;
    _profile = null;
    _loading = true;
    _notify();
    if (user != null) {
      try {
        final row = await _client
            .from('profiles')
            .select('id, username, role, approved, rejected, created_at')
            .eq('id', user.id)
            .maybeSingle();
        _profile = row == null ? null : Map<String, dynamic>.from(row);
      } catch (error) {
        _error = _friendlyError(error);
      }
    }
    _loading = false;
    _notify();
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('email_provider_disabled')) {
      return 'Username sign-in needs Supabase Email authentication enabled. Turn on the Email provider in your Supabase project settings, then try again.';
    }
    if (message.contains('Invalid login credentials')) {
      return 'Username or password is incorrect.';
    }
    if (message.contains('User already registered')) {
      return 'This username already has an account. Sign in instead.';
    }
    if (message.contains('Password should be')) {
      return 'The password does not meet the password rules configured in Supabase.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  String _authEmail(String username) {
    final normalized = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.-]{3,24}$').hasMatch(normalized)) {
      throw const FormatException(
        'Username must be 3–24 characters using letters, numbers, dot, dash, or underscore.',
      );
    }
    return '$normalized@$_authDomain';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
