import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/evacuation_center_repository.dart';
import 'hotline_reconnect_mixin.dart';

/// Shown when the device is offline and no saved evacuation centers exist on
/// this device yet (first use).
const String evacuationCenterFirstUseOfflineMessage =
    "You're offline and no saved evacuation center information is available on "
    'this device yet.\n\nConnect to the internet once to download and save it '
    'for offline viewing.';

/// Offline-first data flow shared by every Evacuation Center screen.
///
/// The SQLite cache is ALWAYS read and displayed first, regardless of
/// connectivity. Connectivity only decides whether the API refresh succeeds; it
/// never gates cache loading. A refresh failure never discards the data the
/// cache already returned.
mixin EvacuationCenterCacheFirstMixin<T extends StatefulWidget>
    on HotlineReconnectMixin<T> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> centers = [];
  DateTime? lastUpdated;
  bool showingSaved = false;

  bool _loadInProgress = false;
  int _lastRefreshToken = 0;

  /// Fallback role used when [AuthService.currentRole] is unavailable.
  String get centerFallbackRole => 'barangay';

  /// Current search text, provided by the screen, used for local filtering.
  String get centerSearch => '';

  /// Token the host bumps (e.g. after saving or editing a center) to force a
  /// fresh reload.
  int get centerRefreshToken => 0;

  String get _role => AuthService.currentRole ?? centerFallbackRole;

  @override
  void initState() {
    super.initState();
    _lastRefreshToken = centerRefreshToken;
    loadCenters();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (centerRefreshToken != _lastRefreshToken) {
      _lastRefreshToken = centerRefreshToken;
      loadCenters();
    }
  }

  @override
  void onNetworkRestored() => loadCenters();

  /// Reads the cache first, then refreshes from the API. A refresh failure
  /// never discards the data the cache already returned.
  Future<void> loadCenters() async {
    if (_loadInProgress) return;
    _loadInProgress = true;

    setState(() {
      isLoading = true;
      errorMessage = null;
      showingSaved = false;
    });

    final userId = AuthService.currentUserId ?? 0;
    final barangayId = AuthService.currentBarangayId;
    final municipality = AuthService.effectiveMunicipality;
    final search = centerSearch;

    final cached = await EvacuationCenterRepository.instance.getCached(
      userId: userId,
      role: _role,
      barangayId: barangayId,
      municipality: municipality,
      search: search,
    );

    if (!mounted) {
      _loadInProgress = false;
      return;
    }

    if (cached.hasCache) {
      setState(() {
        centers = cached.centers;
        lastUpdated = cached.lastUpdated;
        isLoading = false;
      });
    }

    if (!await _isNetworkAvailable()) {
      if (!mounted) {
        _loadInProgress = false;
        return;
      }
      _applyRefreshFailure(cached);
      _loadInProgress = false;
      return;
    }

    final refreshed = await EvacuationCenterRepository.instance.refresh(
      userId: userId,
      role: _role,
      barangayId: barangayId,
      barangayName: AuthService.currentBarangayName,
      municipality: municipality,
      search: search,
    );

    if (!mounted) {
      _loadInProgress = false;
      return;
    }

    if (refreshed.offline) {
      _applyRefreshFailure(cached);
      _loadInProgress = false;
      return;
    }

    setState(() {
      centers = refreshed.centers;
      lastUpdated = refreshed.lastUpdated;
      showingSaved = false;
      isLoading = false;
    });
    _loadInProgress = false;
  }

  void _applyRefreshFailure(EvacuationCenterLoadResult cached) {
    setState(() {
      isLoading = false;
      if (cached.hasCache) {
        centers = cached.centers;
        lastUpdated = cached.lastUpdated;
        showingSaved = true;
      } else {
        errorMessage = evacuationCenterFirstUseOfflineMessage;
      }
    });
  }

  /// True when the device currently has no network connection. Used to block
  /// write actions (add/edit/delete) while viewing saved data.
  Future<bool> isOffline() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.none);
  }

  /// Blocks a write action while offline, explaining that reconnecting is
  /// required. Returns true when the caller must abort the action.
  Future<bool> guardOfflineAction() async {
    if (!await isOffline()) return false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reconnect to the internet to make changes.'),
          backgroundColor: AppColors.warningYellow,
        ),
      );
    }
    return true;
  }

  Future<bool> _isNetworkAvailable() async => !await isOffline();
}
