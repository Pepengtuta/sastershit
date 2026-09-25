import 'assistance_cache_database.dart';
import 'evacuation_center_service.dart';

/// Fetches the live evacuation center snapshot for a scope. Injectable so
/// tests can drive success/failure without a network.
typedef EvacuationCenterFetcher =
    Future<Map<String, dynamic>> Function({
      required String role,
      int? barangayId,
      String? barangayName,
      String? municipality,
    });

/// Result of loading evacuation centers, either from the local cache or from
/// the network.
class EvacuationCenterLoadResult {
  const EvacuationCenterLoadResult({
    this.centers = const [],
    this.lastUpdated,
    this.hasCache = false,
    this.offline = false,
    this.message,
  });

  /// The centers to display (already filtered by the current search).
  final List<Map<String, dynamic>> centers;

  /// The last successful update time from the network (null before the first
  /// successful fetch).
  final DateTime? lastUpdated;

  /// True when a cached snapshot exists for this scope, regardless of whether
  /// the current search matched any of its rows.
  final bool hasCache;

  /// True when the network request failed. The caller should keep showing
  /// whatever cached data it already displayed.
  final bool offline;

  /// The failure message to surface when there is no cache to fall back to.
  final String? message;
}

/// Coordinates the evacuation center API with the local SQLite cache.
///
/// The cache is scoped by acting user + role + barangay + municipality, so
/// cached centers can never leak between users with different access scopes.
/// The search filter is applied locally to the cached snapshot using the same
/// rules as `api/get_evacuation_centers.php`, so searching keeps working
/// offline. The network snapshot is always stored unfiltered, so a later search
/// never hides rows the server did not send.
class EvacuationCenterRepository {
  EvacuationCenterRepository({
    AssistanceCacheDatabase? cache,
    EvacuationCenterFetcher? fetcher,
  }) : _cache = cache ?? AssistanceCacheDatabase.instance,
       _fetch = fetcher ?? _defaultFetch;

  final AssistanceCacheDatabase _cache;
  final EvacuationCenterFetcher _fetch;

  static EvacuationCenterRepository instance = EvacuationCenterRepository();

  static const String dataset = 'evacuation_centers';

  static Future<Map<String, dynamic>> _defaultFetch({
    required String role,
    int? barangayId,
    String? barangayName,
    String? municipality,
  }) {
    return EvacuationCenterService.getEvacuationCenters(
      role: role,
      barangayId: barangayId,
      barangayName: barangayName,
      search: '',
      municipality: municipality,
    );
  }

  /// Builds the cache key that must match before cached data may be reused.
  ///
  /// The acting user id is always included so one user can never see another
  /// user's cached centers; role, barangay, and municipality encode the access
  /// scope the server used for the snapshot.
  static String buildCacheKey({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
  }) {
    final muni = (municipality == null || municipality.trim().isEmpty)
        ? ''
        : municipality.trim().toLowerCase();
    return 'evac_centers|u$userId|r${role.trim().toLowerCase()}'
        '|b${barangayId?.toString() ?? 'all'}|m$muni';
  }

  /// Applies the current search to a cached snapshot, mirroring the LIKE
  /// clauses in `api/get_evacuation_centers.php`.
  static List<Map<String, dynamic>> filterLocally(
    List<Map<String, dynamic>> rows, {
    required String search,
  }) {
    final term = search.trim().toLowerCase();
    if (term.isEmpty) return rows;
    return rows.where((row) {
      final haystack = [
        row['center_name']?.toString() ?? '',
        row['barangay']?.toString() ?? '',
        row['status']?.toString() ?? '',
        row['center_type']?.toString() ?? '',
      ];
      return haystack.any((value) => value.toLowerCase().contains(term));
    }).toList();
  }

  /// Reads the cached snapshot for the current scope and filters it locally.
  /// Always returns immediately without touching the network.
  Future<EvacuationCenterLoadResult> getCached({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    String search = '',
  }) async {
    final cacheKey = buildCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
    );
    final raw = await _cache.getSnapshot(cacheKey);
    final rows = _asMapList(raw);
    final lastUpdated = await _cache.getLastUpdated(cacheKey);
    return EvacuationCenterLoadResult(
      centers: filterLocally(rows, search: search),
      lastUpdated: lastUpdated,
      hasCache: rows.isNotEmpty,
    );
  }

  /// Fetches the current scope snapshot from the API, saves it to SQLite on
  /// success, and returns the locally-filtered result.
  ///
  /// On failure it leaves the cache untouched and returns an
  /// [EvacuationCenterLoadResult] with [EvacuationCenterLoadResult.offline] set
  /// to true so the caller keeps showing the saved centers.
  Future<EvacuationCenterLoadResult> refresh({
    required int userId,
    required String role,
    int? barangayId,
    String? barangayName,
    String? municipality,
    String search = '',
  }) async {
    final cacheKey = buildCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
    );

    final result = await _fetch(
      role: role,
      barangayId: barangayId,
      barangayName: barangayName,
      municipality: municipality,
    );

    if (result['success'] != true) {
      return EvacuationCenterLoadResult(
        offline: true,
        message:
            result['message']?.toString() ?? 'Failed to load evacuation centers.',
      );
    }

    final rows = _asMapList(result['data']);
    final now = DateTime.now();
    await _cache.replaceSnapshot(
      cacheKey: cacheKey,
      dataset: dataset,
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
      payload: rows,
      updatedAt: now,
    );

    return EvacuationCenterLoadResult(
      centers: filterLocally(rows, search: search),
      lastUpdated: now,
      hasCache: rows.isNotEmpty,
    );
  }

  static List<Map<String, dynamic>> _asMapList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
