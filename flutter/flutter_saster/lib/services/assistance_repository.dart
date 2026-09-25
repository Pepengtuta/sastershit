import 'assistance_cache_database.dart';
import 'assistance_service.dart';

/// Fetches one center's needs document. Injectable for tests.
typedef CenterNeedsFetcher =
    Future<Map<String, dynamic>> Function({required int evacCenterId});

/// Fetches the assistance board document for a municipality scope. Injectable
/// for tests.
typedef AssistanceBoardFetcher =
    Future<Map<String, dynamic>> Function({String? municipality});

/// Result of loading one evacuation center's needs/profile/ledger, either from
/// the local cache or from the network.
class CenterNeedsLoadResult {
  const CenterNeedsLoadResult({
    this.data,
    this.lastUpdated,
    this.hasCache = false,
    this.offline = false,
    this.message,
  });

  /// The center-needs document (center, profile, needs, fulfillment, ledger,
  /// incident, computed headcount), or null when nothing is cached.
  final Map<String, dynamic>? data;

  final DateTime? lastUpdated;
  final bool hasCache;
  final bool offline;
  final String? message;
}

/// Result of loading the Needs & Assistance board, either from the local cache
/// or from the network.
class AssistanceBoardLoadResult {
  const AssistanceBoardLoadResult({
    this.data,
    this.lastUpdated,
    this.hasCache = false,
    this.offline = false,
    this.message,
  });

  /// The board document (scope label, centers, summary, zero-pledge centers),
  /// or null when nothing is cached.
  final Map<String, dynamic>? data;

  final DateTime? lastUpdated;
  final bool hasCache;
  final bool offline;
  final String? message;
}

/// Coordinates the center-needs and assistance-board APIs with the local SQLite
/// cache.
///
/// Each snapshot is scoped by acting user plus the server-side access scope
/// (center id for needs, role + municipality for the board), so cached data can
/// never leak between users or scopes.
class AssistanceRepository {
  AssistanceRepository({
    AssistanceCacheDatabase? cache,
    CenterNeedsFetcher? needsFetcher,
    AssistanceBoardFetcher? boardFetcher,
  }) : _cache = cache ?? AssistanceCacheDatabase.instance,
       _fetchNeeds = needsFetcher ?? _defaultNeedsFetch,
       _fetchBoard = boardFetcher ?? _defaultBoardFetch;

  final AssistanceCacheDatabase _cache;
  final CenterNeedsFetcher _fetchNeeds;
  final AssistanceBoardFetcher _fetchBoard;

  static AssistanceRepository instance = AssistanceRepository();

  static const String needsDataset = 'center_needs';
  static const String boardDataset = 'assistance_board';

  static Future<Map<String, dynamic>> _defaultNeedsFetch({
    required int evacCenterId,
  }) {
    return AssistanceService.getCenterNeeds(evacCenterId: evacCenterId);
  }

  static Future<Map<String, dynamic>> _defaultBoardFetch({
    String? municipality,
  }) {
    return AssistanceService.getBoard(municipality: municipality);
  }

  /// Cache key for one center's needs. Includes the center id because the
  /// server returns a single-center document.
  static String buildNeedsCacheKey({
    required int userId,
    required int evacCenterId,
  }) {
    return 'center_needs|u$userId|e$evacCenterId';
  }

  /// Cache key for the board. The acting user plus role and municipality encode
  /// the access scope the server used for the snapshot.
  static String buildBoardCacheKey({
    required int userId,
    required String role,
    String? municipality,
  }) {
    final muni = (municipality == null || municipality.trim().isEmpty)
        ? ''
        : municipality.trim().toLowerCase();
    return 'assistance_board|u$userId|r${role.trim().toLowerCase()}|m$muni';
  }

  Future<CenterNeedsLoadResult> getCachedCenterNeeds({
    required int userId,
    required int evacCenterId,
  }) async {
    final cacheKey = buildNeedsCacheKey(
      userId: userId,
      evacCenterId: evacCenterId,
    );
    final data = await _cache.getSnapshot(cacheKey);
    final lastUpdated = await _cache.getLastUpdated(cacheKey);
    return CenterNeedsLoadResult(
      data: _asMap(data),
      lastUpdated: lastUpdated,
      hasCache: data is Map,
    );
  }

  Future<CenterNeedsLoadResult> refreshCenterNeeds({
    required int userId,
    required int evacCenterId,
  }) async {
    final cacheKey = buildNeedsCacheKey(
      userId: userId,
      evacCenterId: evacCenterId,
    );

    final result = await _fetchNeeds(evacCenterId: evacCenterId);

    if (result['success'] != true || result['data'] is! Map) {
      return CenterNeedsLoadResult(
        offline: true,
        message: result['message']?.toString() ?? 'Failed to load center needs.',
      );
    }

    final data = Map<String, dynamic>.from(result['data'] as Map);
    final now = DateTime.now();
    await _cache.replaceSnapshot(
      cacheKey: cacheKey,
      dataset: needsDataset,
      userId: userId,
      role: null,
      payload: data,
      updatedAt: now,
    );

    return CenterNeedsLoadResult(
      data: data,
      lastUpdated: now,
      hasCache: true,
    );
  }

  Future<AssistanceBoardLoadResult> getCachedBoard({
    required int userId,
    required String role,
    String? municipality,
  }) async {
    final cacheKey = buildBoardCacheKey(
      userId: userId,
      role: role,
      municipality: municipality,
    );
    final data = await _cache.getSnapshot(cacheKey);
    final lastUpdated = await _cache.getLastUpdated(cacheKey);
    return AssistanceBoardLoadResult(
      data: _asMap(data),
      lastUpdated: lastUpdated,
      hasCache: data is Map,
    );
  }

  Future<AssistanceBoardLoadResult> refreshBoard({
    required int userId,
    required String role,
    String? municipality,
  }) async {
    final cacheKey = buildBoardCacheKey(
      userId: userId,
      role: role,
      municipality: municipality,
    );

    final result = await _fetchBoard(municipality: municipality);

    if (result['success'] != true || result['data'] is! Map) {
      return AssistanceBoardLoadResult(
        offline: true,
        message:
            result['message']?.toString() ??
            'Failed to load the assistance board.',
      );
    }

    final data = Map<String, dynamic>.from(result['data'] as Map);
    final now = DateTime.now();
    await _cache.replaceSnapshot(
      cacheKey: cacheKey,
      dataset: boardDataset,
      userId: userId,
      role: role,
      municipality: municipality,
      payload: data,
      updatedAt: now,
    );

    return AssistanceBoardLoadResult(
      data: data,
      lastUpdated: now,
      hasCache: true,
    );
  }

  static Map<String, dynamic>? _asMap(Object? raw) {
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }
}
