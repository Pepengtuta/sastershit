import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/hotline_repository.dart';
import 'hotline_reconnect_mixin.dart';

/// Shown when the device is offline and no saved hotlines exist on this device
/// yet (first use). The raw "Connection failed" message is a poor experience
/// here, so offline first-use gets its own friendly copy.
const String hotlineFirstUseOfflineMessage =
    "You're offline and no saved hotline information is available on this "
    'device yet.\n\nConnect to the internet once to download and save hotlines '
    'for offline viewing.';

/// Offline-first data flow shared by every Hotline screen.
///
/// Contract (defined here once, applied everywhere):
///  - The SQLite cache is ALWAYS read and displayed first, regardless of
///    connectivity.
///  - Connectivity only decides whether the API refresh succeeds; it never
///    gates cache loading.
///  - The screen reloads when it is created / its tab is reopened (initState),
///    when the host bumps [hotlineRefreshToken], when the app is resumed, and
///    when connectivity is restored. Connectivity events are retry triggers
///    only — they are never required for the initial cache load.
mixin HotlineCacheFirstMixin<T extends StatefulWidget> on HotlineReconnectMixin<T> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> hotlines = [];
  DateTime? lastUpdated;
  bool showingSaved = false;

  bool _loadInProgress = false;
  int _lastRefreshToken = 0;

  /// Fallback role used when [AuthService.currentRole] is unavailable.
  String get hotlineFallbackRole => 'barangay';

  /// Municipality used to scope the cache snapshot, provided by the screen.
  String? get hotlineMunicipality => AuthService.effectiveMunicipality;

  /// Current search text, provided by the screen, used for local filtering.
  String get hotlineSearch => '';

  /// Current selected category, provided by the screen.
  String get hotlineCategory => 'All';

  /// Token the host bumps (e.g. after saving or editing a hotline) to force a
  /// fresh reload.
  int get hotlineRefreshToken => 0;

  @override
  void initState() {
    super.initState();
    _lastRefreshToken = hotlineRefreshToken;
    loadHotlines();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (hotlineRefreshToken != _lastRefreshToken) {
      _lastRefreshToken = hotlineRefreshToken;
      loadHotlines();
    }
  }

  @override
  void onNetworkRestored() => loadHotlines();

  /// Reads the cache first, then refreshes from the API. A refresh failure
  /// never discards the data the cache already returned.
  Future<void> loadHotlines() async {
    if (_loadInProgress) return;
    _loadInProgress = true;

    setState(() {
      isLoading = true;
      errorMessage = null;
      showingSaved = false;
    });

    final role = AuthService.currentRole ?? hotlineFallbackRole;
    final userId = AuthService.currentUserId ?? 0;
    final barangayId = AuthService.currentBarangayId;
    final municipality = hotlineMunicipality;
    final search = hotlineSearch;
    final category = hotlineCategory;

    final cached = await HotlineRepository.instance.getCached(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
      search: search,
      category: category,
    );

    if (!mounted) {
      _loadInProgress = false;
      return;
    }

    if (cached.hasCache) {
      setState(() {
        hotlines = cached.hotlines;
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

    final refreshed = await HotlineRepository.instance.refresh(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
      search: search,
      category: category,
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
      hotlines = refreshed.hotlines;
      lastUpdated = refreshed.lastUpdated;
      showingSaved = false;
      isLoading = false;
    });
    _loadInProgress = false;
  }

  void _applyRefreshFailure(HotlineLoadResult cached) {
    setState(() {
      isLoading = false;
      if (cached.hasCache) {
        hotlines = cached.hotlines;
        lastUpdated = cached.lastUpdated;
        showingSaved = true;
      } else {
        errorMessage = hotlineFirstUseOfflineMessage;
      }
    });
  }

  Future<bool> _isNetworkAvailable() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}