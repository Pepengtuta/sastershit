import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite storage for the offline Dashboard feature.
///
/// Two tables:
/// - [snapshotsTable] : one row per scope cache key holding the last successful
///   dashboard summary document (the whole `data` map from the API) as JSON.
///   PRIMARY KEY (cache_key) makes duplicate snapshots impossible.
/// - [metaTable]      : one row per cache key with the last successful update
///   time and the access scope that produced the snapshot.
///
/// The cache key is derived from the acting user, their access scope (role,
/// barangay, municipality, sub-role), and the month/year filter, so a cached
/// summary can never leak across users, scopes, or months.
class DashboardCacheDatabase {
  DashboardCacheDatabase({this._dbName = 'saster_dashboard_cache.db'});

  static final DashboardCacheDatabase instance = DashboardCacheDatabase();

  static const String snapshotsTable = 'cached_dashboard_snapshots';
  static const String metaTable = 'dashboard_cache_meta';

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
          CREATE TABLE $snapshotsTable (
            cache_key TEXT NOT NULL PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $metaTable (
            cache_key TEXT NOT NULL PRIMARY KEY,
            user_id INTEGER,
            role TEXT,
            barangay_id INTEGER,
            municipality TEXT,
            updated_at TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Atomically replaces the cached dashboard snapshot for [cacheKey].
  ///
  /// The previous snapshot and metadata are replaced in one transaction, so a
  /// failure rolls back and the working cache is never left half-written or
  /// duplicated.
  Future<void> replaceSnapshot({
    required String cacheKey,
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    required Map<String, dynamic> payload,
    required DateTime updatedAt,
  }) async {
    final db = await database;
    final timestamp = updatedAt.toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(snapshotsTable, {
        'cache_key': cacheKey,
        'payload': jsonEncode(payload),
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert(metaTable, {
        'cache_key': cacheKey,
        'user_id': userId,
        'role': role,
        'barangay_id': barangayId,
        'municipality': municipality,
        'updated_at': timestamp,
        'created_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// The decoded dashboard summary for [cacheKey], or null when this scope was
  /// never synced.
  Future<Map<String, dynamic>?> getSnapshot(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      snapshotsTable,
      columns: ['payload'],
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['payload']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  /// The last successful network update for [cacheKey], or null if the scope
  /// was never fetched successfully.
  Future<DateTime?> getLastUpdated(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      metaTable,
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
}