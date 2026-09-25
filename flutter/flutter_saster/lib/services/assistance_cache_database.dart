import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite storage for the offline-capable Evacuation Centers, Center
/// Needs, and Needs & Assistance Board features.
///
/// Two tables:
/// - [snapshotsTable] : one row per scope cache key holding the last successful
///   snapshot as JSON (a list of center rows, or a center-needs / board
///   document). PRIMARY KEY (cache_key) makes duplicate snapshots impossible.
/// - [metaTable]      : one row per cache key with the last successful update
///   time and the access scope that produced the snapshot.
///
/// The cache key is derived from the acting user, the dataset, and the request
/// scope, so cached data can never leak between users or between different
/// access scopes.
class AssistanceCacheDatabase {
  AssistanceCacheDatabase({this._dbName = 'saster_assistance_cache.db'});

  static final AssistanceCacheDatabase instance = AssistanceCacheDatabase();

  static const String snapshotsTable = 'cached_snapshots';
  static const String metaTable = 'assistance_cache_meta';

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
            dataset TEXT NOT NULL,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $metaTable (
            cache_key TEXT NOT NULL PRIMARY KEY,
            dataset TEXT NOT NULL,
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

  /// Atomically replaces the cached snapshot for [cacheKey].
  ///
  /// The previous snapshot and metadata are replaced in one transaction, so a
  /// failure rolls back and the working cache is never left half-written or
  /// duplicated.
  Future<void> replaceSnapshot({
    required String cacheKey,
    required String dataset,
    required int userId,
    String? role,
    int? barangayId,
    String? municipality,
    required Object payload,
    required DateTime updatedAt,
  }) async {
    final db = await database;
    final timestamp = updatedAt.toUtc().toIso8601String();
    final encoded = jsonEncode(payload);

    await db.transaction((txn) async {
      await txn.insert(snapshotsTable, {
        'cache_key': cacheKey,
        'dataset': dataset,
        'payload': encoded,
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert(metaTable, {
        'cache_key': cacheKey,
        'dataset': dataset,
        'user_id': userId,
        'role': role,
        'barangay_id': barangayId,
        'municipality': municipality,
        'updated_at': timestamp,
        'created_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// The decoded cached snapshot for [cacheKey] (a List or Map), or null when
  /// this scope was never synced.
  Future<Object?> getSnapshot(String cacheKey) async {
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
    return jsonDecode(raw);
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
