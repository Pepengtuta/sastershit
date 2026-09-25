import 'package:connectivity_plus/connectivity_plus.dart';

import 'create_incident_cache_database.dart';
import 'disaster_type_service.dart';
import 'evacuation_center_service.dart';

/// Result of loading one piece of Create Incident reference data, either from
/// the local SQLite cache or from the network.
class CreateIncidentReferenceResult {
  const CreateIncidentReferenceResult({
    this.rows = const [],
    this.lastUpdated,
    this.hasCache = false,
    this.offline = false,
    this.message,
  });

  /// The rows to display (disaster types or evacuation centers).
  final List<Map<String, dynamic>> rows;

  /// The last successful network update time (null before the first fetch).
  final DateTime? lastUpdated;

  /// True when a cached snapshot exists for this scope.
  final bool hasCache;

  /// True when the network request failed. The caller should keep showing
  /// whatever cached data it already displayed.
  final bool offline;

  /// The failure message to surface when there is no cache to fall back to.
  final String? message;
}

/// Coordinates the Create Incident reference endpoints (disaster types and the
/// barangay's evacuation centers) with the local SQLite cache.
///
/// Following the app-wide offline rule: the SQLite cache is always loaded
/// first and the network request only decides whether a refresh succeeds. On a
/// failed refresh the existing cache is kept untouched and the caller shows a
/// small "saved data" note instead.
class CreateIncidentRepository {
  CreateIncidentRepository({CreateIncidentCacheDatabase? cache})
    : _cache = cache ?? CreateIncidentCacheDatabase.instance;

  final CreateIncidentCacheDatabase _cache;

  static CreateIncidentRepository instance = CreateIncidentRepository();

  /// Builds the scope key for a barangay's evacuation center snapshot.
  ///
  /// The key must match before cached data may be reused: different barangays
  /// (or differently-cased spellings of the same barangay) never share rows.
  static String evacuationCacheKey({
    required int? barangayId,
    required String? barangayName,
  }) {
    final name = (barangayName == null || barangayName.trim().isEmpty)
        ? ''
        : barangayName.trim().toLowerCase();
    return 'evac|b${barangayId?.toString() ?? 'all'}|$name';
  }

  /// Derives the set of natural disaster names from the server rows.
  ///
  /// Used to auto-fill the Affected count only for types that the server marks
  /// as affecting the whole barangay population. Falls back to treating every
  /// type as natural when the server does not expose the flag.
  static Set<String> naturalDisasterNames(List<Map<String, dynamic>> rows) {
    return rows
        .where((row) => (row['is_natural'] ?? 1) == 1)
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  /// Reads the cached disaster types snapshot. Never touches the network.
  Future<CreateIncidentReferenceResult> getCachedDisasterTypes() async {
    final rows = await _cache.getDisasterTypes();
    final lastUpdated = await _cache.getDisasterTypesLastUpdated();
    return CreateIncidentReferenceResult(
      rows: rows,
      lastUpdated: lastUpdated,
      hasCache: rows.isNotEmpty,
    );
  }

  /// Fast offline short-circuit so first-use offline never waits for the API
  /// timeout. Falls back to letting the API call decide when the connectivity
  /// report itself fails.
  static Future<bool> _hasNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  /// Fetches the active disaster types from the API and caches them on success.
  ///
  /// On failure the cache is left untouched and [CreateIncidentReferenceResult.offline]
  /// is set so the caller can keep showing the saved types.
  Future<CreateIncidentReferenceResult> refreshDisasterTypes() async {
    if (!await _hasNetwork()) {
      return const CreateIncidentReferenceResult(
        offline: true,
        message: "You're offline.",
      );
    }

    final result = await DisasterTypeService.getDisasterTypes();
    if (result['success'] != true) {
      return CreateIncidentReferenceResult(
        offline: true,
        message: result['message']?.toString() ?? 'Failed to load disaster types.',
      );
    }

    final raw = result['data'];
    final rows = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    final now = DateTime.now();
    await _cache.replaceDisasterTypes(rows: rows, updatedAt: now);

    return CreateIncidentReferenceResult(
      rows: rows,
      lastUpdated: now,
      hasCache: rows.isNotEmpty,
    );
  }

  /// Reads the cached evacuation center snapshot for one barangay scope.
  /// Never touches the network.
  Future<CreateIncidentReferenceResult> getCachedEvacuationCenters({
    required int? barangayId,
    required String? barangayName,
  }) async {
    final id = barangayId ?? 0;
    final name = barangayName ?? '';
    final rows = await _cache.getEvacuationCenters(
      barangayId: id,
      barangayName: name,
    );
    final lastUpdated = await _cache.getEvacuationCentersLastUpdated(
      barangayId: id,
      barangayName: name,
    );
    return CreateIncidentReferenceResult(
      rows: rows,
      lastUpdated: lastUpdated,
      hasCache: rows.isNotEmpty,
    );
  }

  /// Fetches the evacuation centers for the barangay scope from the API and
  /// caches them on success. On failure the cache is kept untouched and
  /// [CreateIncidentReferenceResult.offline] is set.
  Future<CreateIncidentReferenceResult> refreshEvacuationCenters({
    required int? barangayId,
    required String? barangayName,
  }) async {
    if (!await _hasNetwork()) {
      return const CreateIncidentReferenceResult(
        offline: true,
        message: "You're offline.",
      );
    }

    final result = await EvacuationCenterService.getEvacuationCenters(
      role: 'barangay',
      barangayId: barangayId,
      barangayName: barangayName,
    );
    if (result['success'] != true) {
      return CreateIncidentReferenceResult(
        offline: true,
        message: result['message']?.toString() ?? 'Failed to load evacuation centers.',
      );
    }

    final raw = result['data'];
    final rows = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    final now = DateTime.now();
    await _cache.replaceEvacuationCenters(
      barangayId: barangayId ?? 0,
      barangayName: barangayName ?? '',
      rows: rows,
      updatedAt: now,
    );

    return CreateIncidentReferenceResult(
      rows: rows,
      lastUpdated: now,
      hasCache: rows.isNotEmpty,
    );
  }
}