import 'hotline_cache_database.dart';
import 'hotline_service.dart';

/// Result of loading hotlines, either from the local cache or from the
/// network.
class HotlineLoadResult {
  const HotlineLoadResult({
    this.hotlines = const [],
    this.lastUpdated,
    this.hasCache = false,
    this.offline = false,
    this.message,
  });

  /// The hotlines to display (already filtered by the current search/category).
  final List<Map<String, dynamic>> hotlines;

  /// The last successful update time from the network (null before the first
  /// successful fetch).
  final DateTime? lastUpdated;

  /// True when a cached snapshot exists for this scope, regardless of whether
  /// the current search/category filter matched any of its rows.
  final bool hasCache;

  /// True when the network request failed. The caller should keep showing
  /// whatever cached data it already displayed.
  final bool offline;

  /// The failure message to surface when there is no cache to fall back to.
  final String? message;
}

/// Coordinates the existing hotline API with the local SQLite cache.
///
/// The cache is scoped by acting user + role + barangay + municipality, so
/// cached hotlines can never leak between users with different access scopes.
/// Search and category filters are applied locally to the cached snapshot using
/// the same rules as `api/get_hotlines.php`, so filtering keeps working offline.
class HotlineRepository {
  HotlineRepository({HotlineCacheDatabase? cache})
    : _cache = cache ?? HotlineCacheDatabase.instance;

  final HotlineCacheDatabase _cache;

  static HotlineRepository instance = HotlineRepository();

  /// Builds the cache key that must match before cached data may be reused.
  ///
  /// The acting user id is always included so one user can never see another
  /// user's cached hotlines; role, barangay, and municipality encode the access
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
    return 'u$userId|r${role.trim().toLowerCase()}|b${barangayId?.toString() ?? 'all'}|m$muni';
  }

  /// Applies the current search and category filter to a cached snapshot,
  /// mirroring the WHERE clauses in `api/get_hotlines.php`.
  static List<Map<String, dynamic>> filterLocally(
    List<Map<String, dynamic>> rows, {
    required String search,
    required String category,
  }) {
    final term = search.trim().toLowerCase();
    final cat = category.trim().toLowerCase();

    return rows.where((row) {
      if (cat != '' && cat != 'all') {
        if (cat == 'barangay' || cat == 'municipal') {
          final scope = (row['hotline_scope']?.toString() ?? '').toLowerCase();
          if (scope != cat) return false;
        } else {
          final rowCategory = (row['category']?.toString() ?? '').toLowerCase();
          if (!rowCategory.contains(cat)) return false;
        }
      }

      if (term != '') {
        final haystack = [
          row['office_name']?.toString() ?? '',
          row['municipality']?.toString() ?? '',
          row['category']?.toString() ?? '',
          row['telephone_numbers']?.toString() ?? '',
          row['cellphone_numbers']?.toString() ?? '',
          row['hotline_number']?.toString() ?? '',
        ];
        if (!haystack.any((value) => value.toLowerCase().contains(term))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Reads the cached snapshot for the current scope and filters it locally.
  /// Always returns immediately without touching the network.
  Future<HotlineLoadResult> getCached({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    String search = '',
    String category = 'All',
  }) async {
    final cacheKey = buildCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
    );
    final rows = await _cache.getSnapshot(cacheKey);
    final lastUpdated = await _cache.getLastUpdated(cacheKey);
    return HotlineLoadResult(
      hotlines: filterLocally(rows, search: search, category: category),
      lastUpdated: lastUpdated,
      hasCache: rows.isNotEmpty,
    );
  }

  /// Fetches the current scope snapshot from the API, saves it to SQLite on
  /// success, and returns the locally-filtered result.
  ///
  /// On failure it leaves the cache untouched and returns [HotlineLoadResult]
  /// with [HotlineLoadResult.offline] set to true so the caller keeps showing
  /// the saved hotlines.
  Future<HotlineLoadResult> refresh({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    String search = '',
    String category = 'All',
  }) async {
    final cacheKey = buildCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
    );

    final result = await HotlineService.getHotlines(
      role: role,
      barangayId: barangayId,
      municipality: municipality,
    );

    if (result['success'] != true) {
      return HotlineLoadResult(
        offline: true,
        message: result['message']?.toString() ?? 'Failed to load hotlines.',
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
      municipality: municipality,
      rows: rows,
      updatedAt: now,
    );

    return HotlineLoadResult(
      hotlines: filterLocally(rows, search: search, category: category),
      lastUpdated: now,
      hasCache: rows.isNotEmpty,
    );
  }
}
