import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  bool _online = true;

  bool get isOnline => _online;

  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _online = _isUp(results);
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final nowOnline = _isUp(results);
      if (nowOnline != _online) {
        _online = nowOnline;
        notifyListeners();
      }
    });
  }

  bool _isUp(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet || r == ConnectivityResult.vpn);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

