import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectivityStatus { online, offline }

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.statusStream;
});

final isOnlineProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(connectivityStatusProvider);
  return statusAsync.when(
    data: (status) => status == ConnectivityStatus.online,
    loading: () => true, // Assume online while checking
    error: (_, __) => false,
  );
});

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;
  final _controller = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _lastStatus = ConnectivityStatus.offline;

  ConnectivityService() {
    _init();
  }

  Stream<ConnectivityStatus> get statusStream => _controller.stream;
  ConnectivityStatus get currentStatus => _lastStatus;

  void _init() {
    // Check initial status
    _checkConnectivity();

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();

      // No connectivity at all
      if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
        _updateStatus(ConnectivityStatus.offline);
        return;
      }

      // Has Wi-Fi or mobile data — verify actual internet
      final hasInternet = await _hasActualInternet();
      _updateStatus(
        hasInternet ? ConnectivityStatus.online : ConnectivityStatus.offline,
      );
    } catch (_) {
      _updateStatus(ConnectivityStatus.offline);
    }
  }

  /// Actually ping a server to verify internet connectivity.
  /// Wi-Fi connected does NOT guarantee internet access.
  Future<bool> _hasActualInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _updateStatus(ConnectivityStatus status) {
    if (_lastStatus != status) {
      _lastStatus = status;
      _controller.add(status);
      debugPrint('[Connectivity] Status changed: ${status.name}');
    }
  }

  /// Force a connectivity re-check.
  Future<ConnectivityStatus> recheckConnectivity() async {
    await _checkConnectivity();
    return _lastStatus;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
