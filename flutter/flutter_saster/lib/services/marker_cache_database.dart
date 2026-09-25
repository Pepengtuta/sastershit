import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite storage for map markers so the offline base map can show the
/// last successfully synchronized snapshot.
///
/// One table per marker type currently displayed on the map. Each row is
/// keyed by (cache_key, id):
/// - [cacheKey] isolates a scope (user + role + municipality + barangay), so
///   cached records can never leak between users or different access scopes.
/// - PRIMARY KEY (cache_key, id) makes duplicate markers impossible.
/// - The payload keeps the exact field set the API returned (including e.g.
///   `incidents.created_at`), so marker details render identically to live.
///
/// [markerMetaTable] holds one row per cache key with the last successful
/// synchronization time and the scope that produced the snapshot.
class MarkerCacheDatabase {
  MarkerCacheDatabase._();

  static final MarkerCacheDatabase instance = MarkerCacheDatabase._();

  static const String markerMetaTable = 'marker_cache_meta';

  /// Server data keys mapped to their SQLite table.
  static const Map<String, String> markerTables = {
    'barangay_halls': 'cached_barangay_halls',
    'evacuation_centers': 'cached_evacuation_centers',
    'pcf_facilities': 'cached_pcf_facilities',
    'incidents': 'cached_incidents',
  };

  static const String _dbName = 'saster_marker_cache.db';
  static const int _dbVersion = 1;

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
        for (final table in markerTables.values) {
          await db.execute('''
            CREATE TABLE $table (
              cache_key TEXT NOT NULL,
              id INTEGER NOT NULL,
              payload TEXT NOT NULL,
              PRIMARY KEY (cache_key, id)
            )
          ''');
        }
        await db.execute('''
          CREATE TABLE $markerMetaTable (
            cache_key TEXT NOT NULL PRIMARY KEY,
            user_id INTEGER,
            role TEXT NOT NULL,
            barangay_id INTEGER,
            municipality TEXT,
            updated_at TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Atomically replaces the whole cached snapshot for [cacheKey]: deletes
  /// every previous row for the scope and re-inserts the new payloads inside
  /// one transaction. A failure rolls back, so the working cache is never
  /// lost or partially written, and no duplicates can survive a refresh.
  Future<void> replaceSnapshot({
    required String cacheKey,
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    required Map<String, List<Map<String, dynamic>>> data,
    required DateTime updatedAt,
  }) async {
    final db = await database;
    final timestamp = updatedAt.toUtc().toIso8601String();

    await db.transaction((txn) async {
      for (final entry in markerTables.entries) {
        final rows = data[entry.key] ?? const <Map<String, dynamic>>[];
        await txn.delete(
          entry.value,
          where: 'cache_key = ?',
          whereArgs: [cacheKey],
        );

        final batch = txn.batch();
        for (final row in rows) {
          batch.insert(
            entry.value,
            {
              'cache_key': cacheKey,
              'id': int.tryParse(row['id'].toString()) ?? row.hashCode,
              'payload': jsonEncode(row),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }

      await txn.insert(markerMetaTable, {
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

  /// The cached marker snapshot for [cacheKey], shaped exactly like the
  /// server data keys. Empty map when this scope was never synced.
  Future<Map<String, List<Map<String, dynamic>>>> getSnapshot(
    String cacheKey,
  ) async {
    final db = await database;
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in markerTables.entries) {
      final rows = await db.query(
        entry.value,
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
      );
      result[entry.key] = rows
          .map(
            (row) => Map<String, dynamic>.from(
              jsonDecode(row['payload'] as String) as Map,
            ),
          )
          .toList();
    }
    return result;
  }

  /// The last successful network sync time for [cacheKey], or null when the
  /// scope has never synchronized marker data.
  Future<DateTime?> getLastUpdated(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      markerMetaTable,
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