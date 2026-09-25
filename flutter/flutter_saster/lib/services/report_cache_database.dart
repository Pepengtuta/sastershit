import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite storage for the offline Incident Reports feature.
///
/// Four tables:
/// - [listTable]    : one row per scope cache key holding the last successful
///   report list snapshot (the whole `data` array from the API) as JSON.
/// - [listMetaTable]: one row per cache key with the last successful update
///   time and the access scope that produced the snapshot.
/// - [detailTable]  : one row per report holding the cached status timeline and
///   evidence metadata (JSON) so a report's details stay viewable offline.
/// - [thumbnailTable]: compressed photo thumbnail BLOBs per report, keyed by
///   the md5 hash of the source file_url. Limited to the most recent
///   [maxThumbnailReportIds] report ids after every insert batch.
///
/// The list cache key is derived from the acting user and the request scope, so
/// cached data can never leak between users or between different access scopes.
/// Details are keyed by server report id only (timeline + evidence are the same
/// for every viewer of a report).
class ReportCacheDatabase {
  ReportCacheDatabase({this._dbName = 'saster_report_cache.db'});

  static final ReportCacheDatabase instance = ReportCacheDatabase();

  static const String listTable = 'cached_report_lists';
  static const String listMetaTable = 'report_list_cache_meta';
  static const String detailTable = 'cached_report_details';
  static const String thumbnailTable = 'cached_report_thumbnails';

  /// Max number of distinct report ids with cached thumbnails.
  static const int maxThumbnailReportIds = 100;

  static const int _dbVersion = 1;

  final String _dbName;
  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $listTable (
            cache_key   TEXT NOT NULL PRIMARY KEY,
            payload     TEXT NOT NULL,
            updated_at  TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $listMetaTable (
            cache_key     TEXT NOT NULL PRIMARY KEY,
            user_id       INTEGER NOT NULL,
            role          TEXT NOT NULL,
            barangay_id   INTEGER,
            municipality  TEXT,
            sub_role      TEXT,
            updated_at    TEXT NOT NULL,
            created_at    TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $detailTable (
            report_id        INTEGER NOT NULL PRIMARY KEY,
            timeline_payload TEXT,
            evidence_payload TEXT,
            updated_at       TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $thumbnailTable (
            report_id   INTEGER NOT NULL,
            url_hash    TEXT NOT NULL,
            mime_type   TEXT NOT NULL,
            data        BLOB NOT NULL,
            updated_at  TEXT NOT NULL,
            PRIMARY KEY (report_id, url_hash)
          )
        ''');
      },
    );
  }

  /// Atomically replaces the cached report list snapshot for [cacheKey].
  ///
  /// The previous snapshot and metadata are replaced in one transaction, so a
  /// failure rolls back and the working cache is never left half-written.
  Future<void> replaceListSnapshot({
    required String cacheKey,
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    String subRole = '',
    required List<Map<String, dynamic>> rows,
    required DateTime updatedAt,
  }) async {
    final db = await database;
    final timestamp = updatedAt.toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(listTable, {
        'cache_key': cacheKey,
        'payload': jsonEncode(rows),
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert(listMetaTable, {
        'cache_key': cacheKey,
        'user_id': userId,
        'role': role,
        'barangay_id': barangayId,
        'municipality': municipality,
        'sub_role': subRole,
        'updated_at': timestamp,
        'created_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// The cached report list for [cacheKey] as maps shaped like the API rows.
  /// Empty when no cache exists for that scope.
  Future<List<Map<String, dynamic>>> getListSnapshot(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      listTable,
      columns: ['payload'],
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    final raw = rows.first['payload']?.toString();
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// The last successful network update for [cacheKey], or null if the scope
  /// was never fetched successfully.
  Future<DateTime?> getListLastUpdated(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      listMetaTable,
      columns: ['updated_at'],
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['updated_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Atomically replaces the cached detail snapshot (timeline + evidence
  /// metadata) for one report id.
  Future<void> replaceDetailSnapshot({
    required int reportId,
    required List<Map<String, dynamic>> timeline,
    required List<Map<String, dynamic>> evidence,
    required DateTime updatedAt,
  }) async {
    final db = await database;
    final timestamp = updatedAt.toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(detailTable, {
        'report_id': reportId,
        'timeline_payload': jsonEncode(timeline),
        'evidence_payload': jsonEncode(evidence),
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// The cached detail snapshot for [reportId], or null when not cached.
  ///
  /// Returns:
  /// {'timeline': [...], 'evidence': [...], 'updated_at': '...'}
  Future<Map<String, dynamic>?> getDetailSnapshot(int reportId) async {
    final db = await database;
    final rows = await db.query(
      detailTable,
      where: 'report_id = ?',
      whereArgs: [reportId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return {
      'timeline': _decodeList(row['timeline_payload']),
      'evidence': _decodeList(row['evidence_payload']),
      'updated_at': row['updated_at']?.toString(),
    };
  }

  /// Saves one photo thumbnail BLOB, then prunes thumbnails so only the most
  /// recent [maxThumbnailReportIds] distinct report ids are retained.
  Future<void> saveThumbnail({
    required int reportId,
    required String urlHash,
    required String mimeType,
    required Uint8List data,
    required DateTime updatedAt,
  }) async {
    final db = await database;
    final timestamp = updatedAt.toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(thumbnailTable, {
        'report_id': reportId,
        'url_hash': urlHash,
        'mime_type': mimeType,
        'data': data,
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    await _evictThumbnails(db);
  }

  /// The cached photo thumbnails for [reportId] as url_hash -> bytes.
  Future<Map<String, Uint8List>> getThumbnails(int reportId) async {
    final db = await database;
    final rows = await db.query(
      thumbnailTable,
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    final result = <String, Uint8List>{};
    for (final row in rows) {
      final hash = row['url_hash']?.toString();
      final bytes = row['data'];
      if (hash == null || hash.isEmpty || bytes is! Uint8List) continue;
      result[hash] = bytes;
    }
    return result;
  }

  Future<void> _evictThumbnails(Database db) async {
    await db.delete(
      thumbnailTable,
      where: 'report_id NOT IN ('
          'SELECT report_id FROM ('
          '  SELECT report_id, MAX(updated_at) AS last_updated '
          '  FROM $thumbnailTable GROUP BY report_id '
          '  ORDER BY last_updated DESC LIMIT ?'
          ')',
      whereArgs: [maxThumbnailReportIds],
    );
  }

  static List<Map<String, dynamic>> _decodeList(Object? raw) {
    if (raw == null) return const [];
    final decoded = jsonDecode(raw.toString());
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}