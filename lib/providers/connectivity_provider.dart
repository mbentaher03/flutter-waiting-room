import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_connectivity.dart';
import '../services/connectivity_service.dart';

class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _service;
  StreamSubscription<bool>? _subscription;
  Timer? _debounce;
  Timer? _backendRetry;
  AppConnectivity _status = AppConnectivity.checking;
  bool _checkingBackend = false;
  bool _checkAgain = false;
  bool _disposed = false;
  bool _initialized = false;

  ConnectivityProvider(
    this._service, {
    AppConnectivity initialStatus = AppConnectivity.checking,
  }) : _status = initialStatus;

  AppConnectivity get status => _status;
  bool get isOnline => _status == AppConnectivity.online;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _subscription = _service.networkChanges.listen(
      _handleNetworkChange,
      onError: (_) => _setStatus(AppConnectivity.checking),
    );
    try {
      _handleNetworkChange(await _service.hasNetwork());
    } catch (_) {
      _setStatus(AppConnectivity.checking);
    }
  }

  void _handleNetworkChange(bool connected) {
    _debounce?.cancel();
    if (!connected) {
      _backendRetry?.cancel();
      _setStatus(AppConnectivity.offline);
      return;
    }
    _backendRetry?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _checkBackend);
  }

  Future<void> _checkBackend() async {
    if (_disposed) return;
    if (_checkingBackend) {
      _checkAgain = true;
      return;
    }
    _checkingBackend = true;
    try {
      do {
        _checkAgain = false;
        final available = await _service.isSupabaseAvailable();
        if (_disposed) return;
        if (available) {
          _backendRetry?.cancel();
          _setStatus(AppConnectivity.online);
        } else {
          _setStatus(AppConnectivity.backendUnavailable);
          _backendRetry?.cancel();
          _backendRetry = Timer(const Duration(seconds: 15), _checkBackend);
        }
      } while (_checkAgain && !_disposed);
    } finally {
      _checkingBackend = false;
    }
  }

  void _setStatus(AppConnectivity status) {
    if (_disposed || _status == status) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _backendRetry?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
