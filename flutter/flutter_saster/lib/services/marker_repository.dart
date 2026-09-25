import 'map_data_service.dart';
import 'marker_cache_database.dart';

/// Fetches the live map-marker snapshot from the server. Injectable for tests.
typedef MapDataFetcher =
    Future<Map<String, dynamic>> Function({
      required String role,
      int? barangayId,
      int? userId,
      String? municipality,
    });

class MarkerLoadResult {
  const MarkerLoadResult({
    this.data = const {},
    this.lastUpdated,
    this.hasCache = false,
    this.offline = false,
    this.message,
  });

  final Map<String, List<Map<String, dynamic>>> data;
  final DateTime? lastUpdated;
  final bool hasCache;
  final bool offline;
  final String? message;
}

class MarkerRepository {
  MarkerRepository({
    MarkerCacheDatabase? cache,
    MapDataFetcher? fetcher,
  }) : _cache = cache ?? MarkerCacheDatabase.instance,
       _fetch = fetcher ?? _defaultFetch;

  final MarkerCacheDatabase _cache;
  final MapDataFetcher _fetch;

  static MarkerRepository instance = MarkerRepository();

  static Future<Map<String, dynamic>> _defaultFetch({
    required String role,
    int? barangayId,
    int? userId,
    String? municipality,
  }) {
    return MapDataService.getMapData(
      role: role,
      barangayId: barangayId,
      userId: userId,
      municipality: municipality,
    );
  }

  static String buildCacheKey({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
  }) {
    final muni = (municipality == null || municipality.trim().isEmpty)
        ? ''
        : municipality.trim().toLowerCase();
    return 'r:${role.trim().toLowerCase()}'
        '|u:$userId'
        '|m:$muni'
        '|b:${barangayId?.toString() ?? ''}';
  }

  /// Returns the cached snapshot, or an empty result if nothing is cached.
  Future<MarkerLoadResult> getCached({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
  }) async {
    final cacheKey = buildCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
    );
    final lastUpdated = await _cache.getLastUpdated(cacheKey);
    if (lastUpdated == null) return const MarkerLoadResult();
    final snapshot = await _cache.getSnapshot(cacheKey);
    final hasCache = snapshot.values.any((rows) => rows.isNotEmpty);
    return MarkerLoadResult(
      data: snapshot,
      lastUpdated: lastUpdated,
      hasCache: hasCache,
    );
  }

  /// Fetches the live snapshot, stores it on success, and returns the result.
  /// On any failure the cache is kept untouched.
  Future<MarkerLoadResult> refresh({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    int? requestUserId,
    String? requestMunicipality,
  }) async {
    final cacheKey = buildCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
    );

    try {
      final result = await _fetch(
        role: role,
        barangayId: barangayId,
        userId: requestUserId,
        municipality: requestMunicipality,
      );

      if (result['success'] != true || result['data'] is! Map) {
        return MarkerLoadResult(
          offline: true,
          message: result['message']?.toString() ?? 'Failed to load map data.',
        );
      }

      final data = Map<String, dynamic>.from(result['data'] as Map);
      if (!_isComplete(data)) {
        return const MarkerLoadResult(
          offline: true,
          message: 'Incomplete marker data.',
        );
      }

      final normalized = normalize(data);
      final now = DateTime.now();
      await _cache.replaceSnapshot(
        cacheKey: cacheKey,
        userId: userId,
        role: role.toLowerCase(),
        barangayId: barangayId,
        municipality: requestMunicipality,
        data: normalized,
        updatedAt: now,
      );

      return MarkerLoadResult(
        data: normalized,
        lastUpdated: now,
        hasCache: normalized.values.any((rows) => rows.isNotEmpty),
      );
    } catch (error) {
      return MarkerLoadResult(offline: true, message: '$error');
    }
  }

  static bool _isComplete(Map<String, dynamic> data) {
    for (final key in MarkerCacheDatabase.markerTables.keys) {
      if (data[key] is! List) return false;
    }
    return true;
  }

  static Map<String, List<Map<String, dynamic>>> normalize(
    Map<String, dynamic> data,
  ) {
    return {
      for (final key in MarkerCacheDatabase.markerTables.keys)
        key: _asMapList(data[key]),
    };
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
