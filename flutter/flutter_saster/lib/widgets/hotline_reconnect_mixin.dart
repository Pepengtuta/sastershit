import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

mixin HotlineReconnectMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  AppLifecycleListener? _lifecycleListener;
  bool _wasOffline = false;
  DateTime? _lastAutoRetry;

  @protected
  void onNetworkRestored() {}

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _autoRetry);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final connected = !results.contains(ConnectivityResult.none);
    if (!connected) {
      _wasOffline = true;
      return;
    }
    if (_wasOffline) {
      _wasOffline = false;
      _autoRetry();
    }
  }

  void _autoRetry() {
    final now = DateTime.now();
    if (_lastAutoRetry != null && now.difference(_lastAutoRetry!) < const Duration(seconds: 3)) {
      return;
    }
    _lastAutoRetry = now;
    if (mounted) onNetworkRestored();
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    super.dispose();
  }
}