import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_config.dart';
import 'alert_repository.dart';
import 'api_service.dart';
import 'assistance_repository.dart';
import 'auth_service.dart';
import 'create_incident_repository.dart';
import 'dashboard_repository.dart';
import 'evacuation_center_repository.dart';
import 'hotline_repository.dart';
import 'marker_repository.dart';
import 'report_repository.dart';

/// The last completed offline-data sync for one user.
class OfflineSyncRecord {
  const OfflineSyncRecord({this.lastSyncedAt, this.hadFailures = false});

  final DateTime? lastSyncedAt;
  final bool hadFailures;
}

/// Persists the sync status per user (SharedPreferences-backed by default),
/// so the indicator shows the correct state across app restarts.
abstract class OfflineSyncStore {
  Future<OfflineSyncRecord> read(int userId);
  Future<void> write(int userId, OfflineSyncRecord record);
}

class SharedPreferencesOfflineSyncStore implements OfflineSyncStore {
  static String _atKey(int userId) => 'saster_offline_sync|$userId|at';
  static String _failedKey(int userId) => 'saster_offline_sync|$userId|failed';

  @override
  Future<OfflineSyncRecord> read(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawAt = prefs.getString(_atKey(userId));
    final failed =
        prefs.getBool(_failedKey(userId)) ?? false;
    return OfflineSyncRecord(
      lastSyncedAt: (rawAt == null || rawAt.isEmpty)
          ? null
          : DateTime.tryParse(rawAt)?.toLocal(),
      hadFailures: failed,
    );
  }

  @override
  Future<void> write(int userId, OfflineSyncRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final rawAt = record.lastSyncedAt?.toUtc().toIso8601String() ?? '';
    await prefs.setString(_atKey(userId), rawAt);
    await prefs.setBool(_failedKey(userId), record.hadFailures);
  }
}

/// Outcome of one dataset inside a sync run. Datasets that the current role is
/// not allowed to see are reported as [attempted] == false so they never count
/// as updates that "could not" run.
class OfflineSyncDatasetResult {
  const OfflineSyncDatasetResult({
    required this.name,
    required this.ok,
    this.attempted = true,
  });

  final String name;
  final bool ok;
  final bool attempted;
}

/// Runs every allowed dataset for the currently signed-in user and returns the
/// per-dataset outcomes. Injectable for tests.
typedef OfflineDatasetsRunner =
    Future<List<OfflineSyncDatasetResult>> Function();

class OfflineSyncStatus {
  const OfflineSyncStatus({
    this.running = false,
    this.lastSyncedAt,
    this.hadFailures = false,
    this.completedInSession = false,
  });

  final bool running;
  final DateTime? lastSyncedAt;
  final bool hadFailures;

  /// True once at least one sync has finished in this app session.
  final bool completedInSession;

  bool get neverSynced => lastSyncedAt == null;
  bool get ready => !running && lastSyncedAt != null && !hadFailures;
  bool get partial => !running && lastSyncedAt != null && hadFailures;
}

/// How reachable the API host currently looks to the coordinator. Screens pair
/// with this to decide when to refresh cached data after an outage.
enum ApiReachabilityStatus { unknown, checking, reachable, unreachable }

/// Pings the API host and reports whether a usable HTTP response arrived.
typedef ApiPinger = Future<bool> Function();

Future<bool> defaultApiPing() async {
  final result = await ApiService.getJson(
    url: '${ApiConfig.baseUrl}/get_disaster_types.php',
  );
  // "Server error: N" still counts as reachable - the host answered.
  return result['success'] == true ||
      !ApiService.isConnectionFailure(
        message: result['message']?.toString() ?? '',
      );
}

/// App-level coordinator for the global offline-first bootstrap.
///
/// After a login, a restored session, an app resume, or a connectivity restore
/// it quietly downloads every dataset the current role is allowed to see
/// (disaster types, hotlines, evacuation centers, per-center needs, the
/// assistance board, and map markers) into the existing SQLite caches - the
/// user never has to open those pages first.
///
/// Rules mirrored from the offline reports syncer:
/// - Single-flight: concurrent triggers share one in-flight sync.
/// - Connectivity restores are debounced.
/// - Each dataset fails independently, so one bad endpoint never blocks the
///   rest, and the last successful state is always preserved.
/// - No network = no sync attempt (never reported as a failure).
class OfflineSyncCoordinator extends ChangeNotifier {
  OfflineSyncCoordinator({
    OfflineSyncStore? store,
    OfflineDatasetsRunner? runDatasets,
    Future<bool> Function()? hasNetwork,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    ApiPinger? pinger,
    this.debounce = const Duration(seconds: 3),
    this.probeDelays = const [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 20),
      Duration(seconds: 30),
    ],
  }) : _store = store ?? SharedPreferencesOfflineSyncStore(),
       _runDatasets = runDatasets ?? defaultOfflineDatasets,
       _hasNetwork = hasNetwork ?? _defaultHasNetwork,
       _pinger = pinger ?? defaultApiPing,
       _connectivityChanges =
           connectivityChanges ?? Connectivity().onConnectivityChanged;

  static OfflineSyncCoordinator instance = OfflineSyncCoordinator();

  final Duration debounce;
  final OfflineSyncStore _store;
  final OfflineDatasetsRunner _runDatasets;
  final Future<bool> Function() _hasNetwork;
  final ApiPinger _pinger;
  final Stream<List<ConnectivityResult>> _connectivityChanges;

  /// Probe delays used while the API host is unreachable, capped growth.
  @visibleForTesting
  final List<Duration> probeDelays;

  bool _started = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _debounceTimer;
  Future<void>? _runningSync;
  OfflineSyncStatus _status = const OfflineSyncStatus();

  Timer? _probeTimer;
  int _probeIndex = 0;
  Future<void>? _retryInFlight;
  ApiReachabilityStatus _apiStatus = ApiReachabilityStatus.unknown;

  OfflineSyncStatus get status => _status;

  /// Whether the API host is currently believed reachable.
  ApiReachabilityStatus get apiStatus => _apiStatus;

  void _setApiStatus(ApiReachabilityStatus next) {
    if (_apiStatus == next) return;
    _apiStatus = next;
    notifyListeners();
  }

  /// Starts listening for connectivity restores and runs an initial sync for
  /// the current session. Safe to call more than once.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    ApiService.onConnectionFailure = _onApiConnectionFailure;

    _connectivitySub = _connectivityChanges.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        // Connectivity came back: one coordinated retry (health check first).
        _scheduleDebounced();
      } else {
        // No connectivity at all: stop probing until it is restored.
        _cancelProbe();
      }
    });

    await refreshFromStore();
    syncNow();
  }

  /// App returned to foreground: one coordinated retry (network gate first).
  Future<void> handleAppResumed() async {
    if (await _hasNetwork()) {
      await retryConnection();
    } else {
      _cancelProbe();
    }
  }

  /// Single-flight coordinated retry: resets the API circuit breaker, recreates
  /// the HTTP client (stale sockets), re-runs a health check, and only then
  /// re-syncs the offline data. Connectivity restore and app resume both funnel
  /// through here, so the two events never fire two retries.
  Future<void> retryConnection() async {
    final inFlight = _retryInFlight;
    if (inFlight != null) return inFlight;

    final userId = AuthService.currentUserId;
    if (userId == null) return;

    late final Future<void> future;
    future = () async {
      try {
        await _coordinatedRetry(userId);
      } catch (error) {
        debugPrint('[OfflineSyncCoordinator] coordinated retry failed: $error');
      } finally {
        if (identical(_retryInFlight, future)) _retryInFlight = null;
      }
    }();
    _retryInFlight = future;
    return future;
  }

  void _onApiConnectionFailure() {
    if (_retryInFlight != null || _probeTimer != null) return;
    _setApiStatus(ApiReachabilityStatus.unreachable);
    _scheduleProbe();
  }

  Future<void> _coordinatedRetry(int userId) async {
    if (!await _hasNetwork()) {
      // No connectivity to probe: stay quiet, Wi-Fi restore will retrigger.
      return;
    }

    // unreachable -> checking (and never stuck on a stale "No route to host").
    _setApiStatus(ApiReachabilityStatus.checking);

    ApiService.recreateHttpClient();
    ApiService.resetApiBreaker();

    final reachable = await _pingSafely();
    _resetProbeBackoff();

    if (reachable) {
      _setApiStatus(ApiReachabilityStatus.reachable);
      await syncNow();
    } else {
      _setApiStatus(ApiReachabilityStatus.unreachable);
      _scheduleProbe();
    }
  }

  Future<bool> _pingSafely() async {
    try {
      return await _pinger();
    } catch (_) {
      return false;
    }
  }

  void _scheduleProbe() {
    _probeTimer?.cancel();
    final delay = _nextProbeDelay();
    _probeTimer = Timer(delay, () {
      _probeTimer = null;
      unawaited(retryConnection());
    });
  }

  Duration _nextProbeDelay() {
    final delays = probeDelays;
    if (_probeIndex >= delays.length) _probeIndex = delays.length - 1;
    final delay = delays[_probeIndex];
    _probeIndex++;
    return delay;
  }

  void _resetProbeBackoff() => _probeIndex = 0;

  void _cancelProbe() {
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  /// Re-reads the persisted status for the currently signed-in user (called
  /// after login / session restore so the app-level indicator is correct).
  Future<void> refreshFromStore() async {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      _status = const OfflineSyncStatus();
      notifyListeners();
      return;
    }
    final record = await _store.read(userId);
    _status = OfflineSyncStatus(
      lastSyncedAt: record.lastSyncedAt,
      hadFailures: record.hadFailures,
      completedInSession: _status.completedInSession,
    );
    notifyListeners();
  }

  void _scheduleDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      unawaited(retryConnection());
    });
  }

  /// Single-flight sync. Returns the in-flight future when one is already
  /// running. Skips quietly when there is no signed-in user or no network.
  /// The in-flight slot is always released in `finally`, even on an unexpected
  /// throw from a dataset runner, so a later call can never be orphaned by a
  /// previous failure.
  Future<void> syncNow() async {
    final running = _runningSync;
    if (running != null) return running;

    final userId = AuthService.currentUserId;
    if (userId == null) return;

    late final Future<void> future;
    future = () async {
      try {
        await _syncWithNetworkCheck(userId);
      } catch (error) {
        debugPrint('[OfflineSyncCoordinator] sync failed: $error');
      } finally {
        if (identical(_runningSync, future)) _runningSync = null;
      }
    }();
    _runningSync = future;
    return future;
  }

  Future<void> _syncWithNetworkCheck(int userId) async {
    if (!await _hasNetwork()) return;
    await _sync(userId);
  }

  Future<void> _sync(int userId) async {
    _status = OfflineSyncStatus(
      running: true,
      lastSyncedAt: _status.lastSyncedAt,
      hadFailures: _status.hadFailures,
      completedInSession: _status.completedInSession,
    );
    notifyListeners();

    try {
      final results = await _runDatasets();
      final attempted = results.where((r) => r.attempted).toList();
      final okCount = attempted.where((r) => r.ok).length;
      final hadFailures = attempted.isNotEmpty && attempted.any((r) => !r.ok);

      final previous = await _store.read(userId);
      var lastSyncedAt = previous.lastSyncedAt;
      if (okCount > 0) lastSyncedAt = DateTime.now();

      await _store.write(
        userId,
        OfflineSyncRecord(
          lastSyncedAt: lastSyncedAt,
          hadFailures: hadFailures,
        ),
      );

      _status = OfflineSyncStatus(
        running: false,
        lastSyncedAt: lastSyncedAt,
        hadFailures: hadFailures,
        completedInSession: true,
      );
      notifyListeners();
    } catch (_) {
      // A runner blew up outside its per-dataset guard (e.g. store failure).
      // Release the running flag so the UI never stays stuck on "preparing".
      _status = OfflineSyncStatus(
        running: false,
        lastSyncedAt: _status.lastSyncedAt,
        hadFailures: _status.hadFailures,
        completedInSession: _status.completedInSession,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _cancelProbe();
    _retryInFlight = null;
    if (ApiService.onConnectionFailure == _onApiConnectionFailure) {
      ApiService.onConnectionFailure = null;
    }
    super.dispose();
  }

  static Future<bool> _defaultHasNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }
}

/// Queues [task] for every [ids] entry running at most [concurrency] at a time.
Future<void> forEachConcurrent<T>(
  List<T> ids,
  int concurrency,
  Future<void> Function(T id) task,
) async {
  var index = 0;
  Future<void> worker() async {
    while (true) {
      final next = index++;
      if (next >= ids.length) return;
      await task(ids[next]);
    }
  }

  final workers = <Future<void>>[
    for (var i = 0; i < concurrency && i < ids.length; i++) worker(),
  ];
  await Future.wait(workers);
}

/// Runs the default dataset list for the currently signed-in user.
///
/// The evacuation-center snapshot is saved first, then its center ids feed the
/// per-center needs pre-cache so "Center Needs" is available offline without
/// visiting each center first. Datasets a role cannot access server-side are
/// skipped (reported as not attempted) and never counted as failures.
Future<List<OfflineSyncDatasetResult>> defaultOfflineDatasets() async {
  final userId = AuthService.currentUserId ?? 0;
  final role = AuthService.currentRole ?? '';
  final barangayId = AuthService.currentBarangayId;
  final barangayName = AuthService.currentBarangayName;
  final normalized = role.trim().toLowerCase();
  final isAdmin =
      normalized == 'superadmin' || normalized == 'pho' || normalized == 'pcf';
  final isBrgy = normalized == 'barangay' || normalized == 'brgy';

  final hotlineMuni =
      AuthService.effectiveMunicipality ?? AuthService.currentMunicipality;
  final evacMuni = AuthService.effectiveMunicipality;
  final boardMuni = AuthService.effectiveMunicipality;
  final markerMuni =
      AuthService.effectiveMunicipality ?? AuthService.currentMunicipality ?? '';

  final results = <OfflineSyncDatasetResult>[];

  // 1. Disaster types (used by the barangay Create Incident screen).
  results.add(
    await _guard('disaster types', () async {
      final result = await CreateIncidentRepository.instance
          .refreshDisasterTypes();
      return !result.offline;
    }),
  );

  // 2. Create Incident evacuation centers (barangay accounts only). This is
  // the same scope the Create Incident screen's dropdown reads, so the center
  // list is available offline without ever opening that screen while online.
  if (isBrgy) {
    results.add(
      await _guard('create incident evacuation centers', () async {
        final result = await CreateIncidentRepository.instance
            .refreshEvacuationCenters(
          barangayId: barangayId,
          barangayName: barangayName,
        );
        return !result.offline;
      }),
    );
  } else {
    results.add(
      const OfflineSyncDatasetResult(
        name: 'create incident evacuation centers',
        ok: true,
        attempted: false,
      ),
    );
  }

  // 4. Hotlines.
  results.add(
    await _guard('hotlines', () async {
      final result = await HotlineRepository.instance.refresh(
        userId: userId,
        role: role,
        barangayId: barangayId,
        municipality: hotlineMuni,
      );
      return !result.offline;
    }),
  );

  // 5. Evacuation centers (snapshot drives the center-needs pre-cache).
  bool evacOk = false;
  List<int> evacCenterIds = const [];
  try {
    final result = await EvacuationCenterRepository.instance.refresh(
      userId: userId,
      role: role,
      barangayId: barangayId,
      barangayName: barangayName,
      municipality: evacMuni,
    );
    evacOk = !result.offline;
    evacCenterIds = result.centers
        .map((c) => int.tryParse(c['id']?.toString() ?? '') ?? 0)
        .where((id) => id > 0)
        .toSet()
        .take(60)
        .toList();
  } catch (_) {
    evacOk = false;
  }
  results.add(
    OfflineSyncDatasetResult(name: 'evacuation centers', ok: evacOk),
  );

  // 6. Per-center needs for every center in the snapshot (bounded, concurrent).
  final canRequestNeeds =
      isAdmin || (isBrgy && (AuthService.isCaptain || AuthService.isSecretary));
  var needsFailed = 0;
  if (evacOk && canRequestNeeds && evacCenterIds.isNotEmpty) {
    await forEachConcurrent(evacCenterIds, 4, (evacCenterId) async {
      try {
        final needs = await AssistanceRepository.instance.refreshCenterNeeds(
          userId: userId,
          evacCenterId: evacCenterId,
        );
        if (needs.offline) needsFailed++;
      } catch (_) {
        needsFailed++;
      }
    });
  }
  results.add(
    OfflineSyncDatasetResult(
      name: 'center needs',
      ok: needsFailed == 0,
      attempted: evacOk && canRequestNeeds && evacCenterIds.isNotEmpty,
    ),
  );

  // 7. Assistance board (admin roles only; the server rejects other roles).
  if (isAdmin) {
    results.add(
      await _guard('assistance board', () async {
        final board = await AssistanceRepository.instance.refreshBoard(
          userId: userId,
          role: role,
          municipality: boardMuni,
        );
        return !board.offline;
      }),
    );
  } else {
    results.add(
      const OfflineSyncDatasetResult(
        name: 'assistance board',
        ok: true,
        attempted: false,
      ),
    );
  }

  // 8. Map markers (cache key always uses the resolved municipality; only
  // admin roles send it to the API).
  results.add(
    await _guard('map markers', () async {
      final markers = await MarkerRepository.instance.refresh(
        userId: userId,
        role: role,
        barangayId: barangayId,
        municipality: markerMuni,
        requestUserId: AuthService.currentUserId,
        requestMunicipality:
            isAdmin && markerMuni.trim().isNotEmpty ? markerMuni : null,
      );
      return !markers.offline;
    }),
  );

  // 9. Alerts (barangay, municipal, and provincial accounts have an alerts
  // screen; the superadmin has none, so that role is skipped, not failed).
  final hasAlertsScreen =
      normalized.isEmpty || !(normalized == 'superadmin');
  if (hasAlertsScreen) {
    results.add(
      await _guard('alerts', () async {
        final alerts = await AlertRepository.instance.refresh(
          userId: userId,
          role: role,
          barangayId: barangayId,
          search: '',
        );
        return !alerts.offline;
      }),
    );
  } else {
    results.add(
      const OfflineSyncDatasetResult(
        name: 'alerts',
        ok: true,
        attempted: false,
      ),
    );
  }

  // 10. Dashboard summary for the current month/year (all four roles have a
  // dashboard screen, so every signed-in account is attempted).
  final now = DateTime.now();
  results.add(
    await _guard('dashboard', () async {
      final dashboard = await DashboardRepository.instance.refresh(
        userId: userId,
        role: role,
        barangayId: barangayId,
        municipality: AuthService.effectiveMunicipality,
        subRole: AuthService.currentSubRole ?? '',
        month: now.month,
        year: now.year,
      );
      return !dashboard.offline;
    }),
  );

  // 11. Report list (all roles with a reports screen).
  results.add(
    await _guard('report list', () async {
      final result = await ReportRepository.instance.getList(
        userId: userId,
        role: role,
        barangayId: barangayId,
        municipality: AuthService.effectiveMunicipality,
        subRole: AuthService.currentSubRole ?? '',
        forUserId: AuthService.isTanod ? userId : null,
      );
      return !result.offline;
    }),
  );

  // 12. Report details (timeline + evidence metadata + photo thumbnails) for
  // the reports just saved by step 9, so cached reports open fully offline.
  final cachedReports = await ReportRepository.instance.getCachedList(
    userId: userId,
    role: role,
    barangayId: barangayId,
    municipality: AuthService.effectiveMunicipality,
    subRole: AuthService.currentSubRole ?? '',
    forUserId: AuthService.isTanod ? userId : null,
  );
  final reportIds = cachedReports
      .map((r) => int.tryParse(r['id']?.toString() ?? '') ?? 0)
      .where((id) => id > 0)
      .toSet()
      .take(100)
      .toList();
  var detailFailed = 0;
  if (reportIds.isNotEmpty) {
    await forEachConcurrent(reportIds, 2, (reportId) async {
      try {
        final result = await ReportRepository.instance.getDetails(
          reportId: reportId,
          userId: userId,
        );
        if (result.offline) detailFailed++;
      } catch (_) {
        detailFailed++;
      }
    });
  }
  results.add(
    OfflineSyncDatasetResult(
      name: 'report details',
      ok: detailFailed == 0,
      attempted: reportIds.isNotEmpty,
    ),
  );

  return results;
}

Future<OfflineSyncDatasetResult> _guard(
  String name,
  Future<bool> Function() run,
) async {
  try {
    return OfflineSyncDatasetResult(name: name, ok: await run());
  } catch (_) {
    return OfflineSyncDatasetResult(name: name, ok: false);
  }
}