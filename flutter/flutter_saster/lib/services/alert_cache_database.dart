import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite storage for the offline Alerts feature.
///
/// Two tables:
/// - [snapshotsTable] : one row per scope cache key holding the last successful
///   alert list (the full `data` list from the API, untouched) as JSON. PRIMARY
///   KEY (cache_key) makes duplicate snapshots impossible.
/// - [metaTable]      : one row per cache key with the last successful update
///   time and the access scope that produced the snapshot.
///
/// The cache key is derived from the acting user plus the access scope (role
/// and barangay), so cached alerts can never leak between users or scopes. The
/// whole alert row is stored verbatim so issue/effective/expiry timestamps are
/// preserved exactly as the server sent them.
class AlertCacheDatabase {
  AlertCacheDatabase({this._dbName = 'saster_alert_cache.db'});

  static final AlertCacheDatabase instance = AlertCacheDatabase();

  static const String snapshotsTable = 'cached_alert_snapshots';
  static const String metaTable = 'alert_cache_meta';

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

  /// Atomically replaces the cached alert snapshot for [cacheKey].
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
    required List<Map<String, dynamic>> payload,
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

  /// The decoded cached alert list for [cacheKey], preserving every server
  /// field (issue/effective/expiry timestamps included). Empty when no cache
  /// exists for that scope.
  Future<List<Map<String, dynamic>>> getSnapshot(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      snapshotsTable,
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
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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