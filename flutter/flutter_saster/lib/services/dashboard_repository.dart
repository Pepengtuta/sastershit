import 'dashboard_cache_database.dart';
import 'dashboard_service.dart';

/// Fetches the dashboard summary for one month/year scope. Injectable for
/// tests.
typedef DashboardSummaryFetcher = Future<Map<String, dynamic>> Function({
  required String role,
  int? barangayId,
  required int month,
  required int year,
  String subRole,
  int? userId,
  String? municipality,
});

/// Result of loading a dashboard summary, either from the local cache or from
/// the network.
class DashboardLoadResult {
  const DashboardLoadResult({
    this.data,
    this.lastUpdated,
    this.hasCache = false,
    this.offline = false,
    this.message,
  });

  /// The dashboard summary document (the `data` map from the API), or null
  /// when nothing is cached.
  final Map<String, dynamic>? data;

  /// The last successful update time from the network (null before the first
  /// successful fetch).
  final DateTime? lastUpdated;

  /// True when a cached snapshot exists for this scope (month/year included).
  final bool hasCache;

  /// True when the network request failed. The caller should keep showing
  /// whatever cached data it already displayed for this month.
  final bool offline;

  /// The failure message to surface when there is no cache to fall back to.
  final String? message;
}

/// Coordinates the existing dashboard API with the local SQLite cache.
///
/// The cache key includes the acting user plus the full server-side access
/// scope (role, barangay, municipality, sub-role) and the month/year filter, so
/// a cached summary can never leak between users, scopes, or months. On a failed
/// refresh the previous snapshot is left untouched (an error or a fresh empty
/// response never replaces saved data).
class DashboardRepository {
  DashboardRepository({
    DashboardCacheDatabase? cache,
    DashboardSummaryFetcher? fetcher,
  }) : _cache = cache ?? DashboardCacheDatabase.instance,
       _fetch = fetcher ?? _defaultFetch;

  final DashboardCacheDatabase _cache;
  final DashboardSummaryFetcher _fetch;

  static DashboardRepository instance = DashboardRepository();

  static Future<Map<String, dynamic>> _defaultFetch({
    required String role,
    int? barangayId,
    required int month,
    required int year,
    String subRole = '',
    int? userId,
    String? municipality,
  }) {
    return DashboardService.getDashboardSummary(
      role: role,
      barangayId: barangayId,
      month: month,
      year: year,
      subRole: subRole,
      userId: userId,
      municipality: municipality,
    );
  }

  /// Builds the cache key that must match before cached data may be reused.
  ///
  /// The acting user id is always included so one user can never see another
  /// user's cached summary; role, barangay, municipality, sub-role, and the
  /// month/year encode the exact scope and filter the server used.
  static String buildCacheKey({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    String subRole = '',
    required int month,
    required int year,
  }) {
    final muni = (municipality == null || municipality.trim().isEmpty)
        ? ''
        : municipality.trim().toLowerCase();
    final sub = subRole.trim().toLowerCase();
    final monthPadded = month.toString().padLeft(2, '0');
    return 'u$userId|r${role.trim().toLowerCase()}|b${barangayId?.toString() ?? 'all'}|m$muni|s$sub|$year-$monthPadded';
  }

  /// Reads the cached summary for the current scope without touching the
  /// network.
  Future<DashboardLoadResult> getCached({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    String subRole = '',
    required int month,
    required int year,
  }) async {
    final cacheKey = buildCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
      subRole: subRole,
      month: month,
      year: year,
    );
    final data = await _cache.getSnapshot(cacheKey);
    final lastUpdated = await _cache.getLastUpdated(cacheKey);
    return DashboardLoadResult(
      data: data,
      lastUpdated: lastUpdated,
      hasCache: data != null,
    );
  }

  /// Fetches the summary for the current scope+month, saves it to SQLite on
  /// success, and returns it.
  ///
  /// On failure it leaves the cache untouched and returns a [DashboardLoadResult]
  /// with [DashboardLoadResult.offline] set to true, so the caller keeps
  /// showing the saved summary for that month instead of an error.
  Future<DashboardLoadResult> refresh({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    String subRole = '',
    required int month,
    required int year,
  }) async {
    final cacheKey = buildCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
      subRole: subRole,
      month: month,
      year: year,
    );

    final result = await _fetch(
      role: role,
      barangayId: barangayId,
      month: month,
      year: year,
      subRole: subRole,
      userId: userId,
      municipality: municipality,
    );

    if (result['success'] != true || result['data'] is! Map) {
      return DashboardLoadResult(
        offline: true,
        message:
            result['message']?.toString() ?? 'Failed to load dashboard summary.',
      );
    }

    final data = Map<String, dynamic>.from(result['data'] as Map);
    final now = DateTime.now();
    await _cache.replaceSnapshot(
      cacheKey: cacheKey,
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
      payload: data,
      updatedAt: now,
    );

    return DashboardLoadResult(
      data: data,
      lastUpdated: now,
      hasCache: true,
    );
  }
}