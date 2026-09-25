import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import 'incident_service.dart';
import 'report_cache_database.dart';

class ReportListLoadResult {
  final List<Map<String, dynamic>> reports;
  final DateTime? lastUpdated;
  final bool hasCache;
  final bool offline;
  final String? message;

  const ReportListLoadResult({
    required this.reports,
    this.lastUpdated,
    this.hasCache = false,
    this.offline = false,
    this.message,
  });
}

class ReportDetailLoadResult {
  final List<Map<String, dynamic>> timeline;
  final List<Map<String, dynamic>> evidence;
  final Map<String, Uint8List> thumbnails;
  final DateTime? lastUpdated;
  final bool hasCache;
  final bool offline;
  final String? message;

  const ReportDetailLoadResult({
    required this.timeline,
    required this.evidence,
    this.thumbnails = const {},
    this.lastUpdated,
    this.hasCache = false,
    this.offline = false,
    this.message,
  });
}

/// Coordinates the report API (list, status timeline, evidence) with the local
/// SQLite cache.
///
/// The list cache is scoped by acting user + role + barangay + municipality +
/// sub-role (+ the tanod `forUserId`), so cached lists can never leak between
/// users or access scopes. Details are cached per report id (timeline and
/// evidence are the same for every viewer of a report), along with compressed
/// photo thumbnails. On a failed refresh the previous snapshot is left
/// untouched - the cache is only written on a successful API response.
class ReportRepository {
  ReportRepository({ReportCacheDatabase? cache}) : _cache = cache ?? ReportCacheDatabase.instance;

  final ReportCacheDatabase _cache;

  static ReportRepository instance = ReportRepository();

  /// Max photo thumbnails cached per report (matches the app's photo limit).
  static const int maxThumbnailsPerReport = 2;
  static const int _thumbMaxEdge = 300;

  /// Builds the cache key that must match before cached data may be reused.
  static String buildListCacheKey({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    String subRole = '',
    int? forUserId,
  }) {
    final muni = (municipality?.trim().isEmpty ?? true)
        ? ''
        : municipality!.trim().toLowerCase();
    final sub = subRole.trim().toLowerCase();
    final forU = forUserId != null ? '|fu$forUserId' : '';
    return 'u$userId|r${role.trim().toLowerCase()}|b${barangayId ?? 'all'}|m$muni|s$sub$forU';
  }

  /// Network-first fetch of the report list for the current scope. Saves the
  /// snapshot to SQLite on success; falls back to the cached snapshot on
  /// failure without ever overwriting a working cache row.
  Future<ReportListLoadResult> getList({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    String subRole = '',
    int? forUserId,
  }) async {
    final cacheKey = buildListCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
      subRole: subRole,
      forUserId: forUserId,
    );

    final normalized = role.trim().toLowerCase();
    final isBarangay = normalized == 'barangay' || normalized == 'brgy';

    final result = await IncidentService.getReports(
      role: role,
      // Barangay: barangay scope, and the tanod sees only their own reports.
      // Admin roles: acting user id (pcf sub-role override + governor checks).
      barangayId: isBarangay ? barangayId : null,
      userId: isBarangay ? forUserId : userId,
      municipality: isBarangay ? null : municipality,
    );

    if (result['success'] != true) {
      return _loadListFromCache(
        cacheKey,
        message: result['message']?.toString() ?? 'Failed to load reports.',
      );
    }

    final raw = result['data'];
    final rows = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    final now = DateTime.now();
    await _cache.replaceListSnapshot(
      cacheKey: cacheKey,
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
      subRole: subRole,
      rows: rows,
      updatedAt: now,
    );

    return ReportListLoadResult(
      reports: rows,
      lastUpdated: now,
      hasCache: rows.isNotEmpty,
    );
  }

  /// Read-only cache lookup (used by the sync coordinator after the list was
  /// saved by [getList]).
  Future<List<Map<String, dynamic>>> getCachedList({
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    String subRole = '',
    int? forUserId,
  }) {
    final cacheKey = buildListCacheKey(
      userId: userId,
      role: role,
      barangayId: barangayId,
      municipality: municipality,
      subRole: subRole,
      forUserId: forUserId,
    );
    return _cache.getListSnapshot(cacheKey);
  }

  Future<ReportListLoadResult> _loadListFromCache(
    String cacheKey, {
    required String message,
  }) async {
    final rows = await _cache.getListSnapshot(cacheKey);
    final lastUpdated = await _cache.getListLastUpdated(cacheKey);
    return ReportListLoadResult(
      reports: rows,
      lastUpdated: lastUpdated,
      hasCache: rows.isNotEmpty,
      offline: true,
      message: message,
    );
  }

  /// Network-first fetch of one report's status timeline + evidence metadata +
  /// photo thumbnails. Saves on success; falls back to cache on failure.
  Future<ReportDetailLoadResult> getDetails({
    required int reportId,
    required int userId,
  }) async {
    final attachments = await IncidentService.getReportAttachments(reportId: reportId);
    final logs = await IncidentService.getReportLogs(reportId: reportId);

    final failed = attachments['success'] != true || logs['success'] != true;
    if (failed) {
      return _loadDetailFromCache(
        reportId,
        message: attachments['message']?.toString() ??
            logs['message']?.toString() ??
            'Unable to load report details.',
      );
    }

    final evidence = List<Map<String, dynamic>>.from(
      (attachments['data'] is List ? attachments['data'] as List : <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)),
    );
    final timeline = List<Map<String, dynamic>>.from(
      (logs['data'] is List ? logs['data'] as List : <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)),
    );

    final now = DateTime.now();
    await _cache.replaceDetailSnapshot(
      reportId: reportId,
      timeline: timeline,
      evidence: evidence,
      updatedAt: now,
    );

    final thumbnails = await _cacheThumbnails(evidence, reportId);

    return ReportDetailLoadResult(
      timeline: timeline,
      evidence: evidence,
      thumbnails: thumbnails,
      lastUpdated: now,
      hasCache: true,
    );
  }

  Future<ReportDetailLoadResult> _loadDetailFromCache(
    int reportId, {
    required String message,
  }) async {
    final snapshot = await _cache.getDetailSnapshot(reportId);
    final thumbnails = await _cache.getThumbnails(reportId);
    final timeline = snapshot?['timeline'] as List<Map<String, dynamic>>? ?? const [];
    final evidence = snapshot?['evidence'] as List<Map<String, dynamic>>? ?? const [];
    final updatedAtRaw = snapshot?['updated_at']?.toString();

    return ReportDetailLoadResult(
      timeline: timeline,
      evidence: evidence,
      thumbnails: thumbnails,
      lastUpdated: updatedAtRaw != null && updatedAtRaw.isNotEmpty
          ? DateTime.tryParse(updatedAtRaw)
          : null,
      hasCache: timeline.isNotEmpty || evidence.isNotEmpty,
      offline: true,
      message: message,
    );
  }

  /// Downloads up to [maxThumbnailsPerReport] photo thumbnails for a report,
  /// resizing each to max 300x300 before storing. Already-cached hashes are
  /// skipped. Failures never throw - thumbnails are best-effort.
  Future<Map<String, Uint8List>> _cacheThumbnails(
    List<Map<String, dynamic>> evidence,
    int reportId,
  ) async {
    final cached = await _cache.getThumbnails(reportId);
    final photos = evidence
        .where(isPhoto)
        .take(maxThumbnailsPerReport)
        .toList();

    for (final photo in photos) {
      final url = photo['file_url']?.toString() ?? '';
      if (url.isEmpty) continue;
      final urlHash = md5.convert(utf8.encode(url)).toString();
      if (cached.containsKey(urlHash)) continue;
      try {
        final bytes = await _download(url);
        if (bytes.isEmpty) continue;
        final resized = await _resize(bytes);
        await _cache.saveThumbnail(
          reportId: reportId,
          urlHash: urlHash,
          mimeType: 'image/png',
          data: resized,
          updatedAt: DateTime.now(),
        );
        cached[urlHash] = resized;
      } catch (_) {
        // Best-effort: a failed thumbnail never breaks the detail sheet.
      }
    }
    return cached;
  }

  /// True for photo evidence (matches the detail sheet's classification).
  static bool isPhoto(Map<String, dynamic> file) {
    final fileType = file['file_type']?.toString().toLowerCase() ?? '';
    final fileName = file['file_name']?.toString().toLowerCase() ?? '';
    return fileType.contains('photo') ||
        fileType.contains('image') ||
        fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png') ||
        fileName.endsWith('.webp') ||
        fileName.endsWith('.gif');
  }

  Future<Uint8List> _download(String url) async {
    final response = await http
        .get(Uri.parse(url), headers: ApiConfig.ngrokHeaders)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return Uint8List(0);
    return response.bodyBytes;
  }

  Future<Uint8List> _resize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: _thumbMaxEdge,
      targetHeight: _thumbMaxEdge,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return bytes;
    return byteData.buffer.asUint8List();
  }
}