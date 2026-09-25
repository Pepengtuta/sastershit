import 'alert_cache_database.dart';
import 'alert_service.dart';

/// Fetches the alert list for one access scope. Injectable for tests.
typedef AlertsFetcher = Future<Map<String, dynamic>> Function({
  required String role,
  int? barangayId,
  int? userId,
  String search,
});

/// Result of loading an alert list, either from the local cache or from the
/// network.
class AlertLoadResult {
  const AlertLoadResult({
    this.alerts = const [],
    this.lastUpdated,
    this.hasCache = false,
    this.offline = false,
    this.message,
  });

  /// The alerts to display (already filtered by the current search locally).
  final List<Map<String, dynamic>> alerts;

  /// The last successful update time from the network (null before the first
  /// successful fetch).
  final DateTime? lastUpdated;

  /// True when a cached snapshot exists for this scope, regardless of whether
  /// the current search matched any of its rows.
  final bool hasCache;

  /// True when the network request failed. The caller should keep showing
  /// whatever cached alerts it already displayed.
  final bool offline;

  /// The failure message to surface when there is no cache to fall back to.
  final String? message;
}

/// Coordinates the existing alerts API with the local SQLite cache.
///
/// The cache key includes the acting user plus role and barangay, so cached
/// alerts can never leak between users or access scopes. The whole scope list
/// is stored verbatim (issue/effective/expiry timestamps preserved); search is
/// applied locally against the cached snapshot using the same fields as
/// `api/get_alerts.php`, so searching keeps working offline.
class AlertRepository {
  AlertRepository({AlertCacheDatabase? cache, AlertsFetcher? fetcher})
    : _cache = cache ?? AlertCacheDatabase.instance,
      _fetch = fetcher ?? _defaultFetch;

  final AlertCacheDatabase _cache;
  final AlertsFetcher _fetch;

  static AlertRepository instance = AlertRepository();

  static Future<Map<String, dynamic>> _defaultFetch({
    required String role,
    int? barangayId,
    int? userId,
    String search = '',
  }) {
    return AlertService.getAlerts(
      role: role,
      barangayId: barangayId,
      userId: userId,
      search: search,
    );
  }

  /// Builds the cache key that must match before cached data may be reused.
  ///
  /// The acting user id is always included so one user can never see another
  /// user's cached alerts; role and barangay encode the access scope the server
  /// used for the snapshot.
  static String buildCacheKey({
    required int userId,
    required String role,
    int? barangayId,
  }) {
    return 'u$userId|r${role.trim().toLowerCase()}|b${barangayId?.toString() ?? 'all'}';
  }

  /// Applies the current search filter to a cached snapshot, mirroring the
  /// WHERE clauses in `api/get_alerts.php` (title, message, alert type,
  /// instructions).
  static List<Map<String, dynamic>> filterLocally(
    List<Map<String, dynamic>> rows, {
    required String search,
  }) {
    final term = search.trim().toLowerCase();
    if (term.isEmpty) return rows;

    return rows.where((row) {
      final haystack = [
        row['title']?.toString() ?? '',
        row['message']?.toString() ?? '',
        row['alert_type']?.toString() ?? '',
        row['instructions']?.toString() ?? '',
      ];
      return haystack.any((value) => value.toLowerCase().contains(term));
    }).toList();
  }

  /// Reads the cached snapshot for the current scope and filters it locally.
  /// Always returns immediately without touching the network.
  Future<AlertLoadResult> getCached({
    required int userId,
    required String role,
    int? barangayId,
    String search = '',
  }) async {
    final cacheKey = buildCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
    );
    final rows = await _cache.getSnapshot(cacheKey);
    final lastUpdated = await _cache.getLastUpdated(cacheKey);
    return AlertLoadResult(
      alerts: filterLocally(rows, search: search),
      lastUpdated: lastUpdated,
      hasCache: rows.isNotEmpty,
    );
  }

  /// Fetches the full scope alert list from the API, saves it to SQLite on
  /// success, and returns the locally-filtered result.
  ///
  /// The whole list is requested (empty search) so the cached snapshot stays
  /// complete and searchable offline. On failure it leaves the cache untouched
  /// and returns an [AlertLoadResult] with [AlertLoadResult.offline] set to
  /// true so the caller keeps showing the saved alerts.
  Future<AlertLoadResult> refresh({
    required int userId,
    required String role,
    int? barangayId,
    String search = '',
  }) async {
    final cacheKey = buildCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
    );

    final result = await _fetch(
      role: role,
      barangayId: barangayId,
      userId: userId,
      search: '',
    );

    if (result['success'] != true) {
      return AlertLoadResult(
        offline: true,
        message: result['message']?.toString() ?? 'Failed to load alerts.',
      );
    }

    final raw = result['data'];
    final rows = raw is List
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final now = DateTime.now();
    await _cache.replaceSnapshot(
      cacheKey: cacheKey,
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: null,
      payload: rows,
      updatedAt: now,
    );

    return AlertLoadResult(
      alerts: filterLocally(rows, search: search),
      lastUpdated: now,
      hasCache: rows.isNotEmpty,
    );
  }
}