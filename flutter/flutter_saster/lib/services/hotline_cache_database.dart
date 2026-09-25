import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite storage for the Emergency Hotlines feature.
///
/// Two tables:
/// - [hotlinesTable]  : cached hotline rows, keyed by a scope cache key and the
///   server hotline id. PRIMARY KEY (cache_key, id) makes duplicate rows
///   impossible.
/// - [metaTable]      : one row per cache key with the last successful update
///   time and the access scope that produced the snapshot.
///
/// The cache key is derived from the acting user and the request scope, so
/// cached data can never leak between users or between different access scopes.
class HotlineCacheDatabase {
  HotlineCacheDatabase._();

  static final HotlineCacheDatabase instance = HotlineCacheDatabase._();

  static const String hotlinesTable = 'cached_hotlines';
  static const String metaTable = 'hotline_cache_meta';

  static const String _dbName = 'saster_hotline_cache.db';
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
        await db.execute('''
          CREATE TABLE $hotlinesTable (
            cache_key TEXT NOT NULL,
            id INTEGER NOT NULL,
            hotline_scope TEXT,
            barangay_id INTEGER,
            barangay_name TEXT,
            office_name TEXT,
            municipality TEXT,
            category TEXT,
            telephone_numbers TEXT,
            cellphone_numbers TEXT,
            hotline_number TEXT,
            remarks TEXT,
            status TEXT,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (cache_key, id)
          )
        ''');
        await db.execute('''
          CREATE TABLE $metaTable (
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

  /// Atomically replaces the cached snapshot for [cacheKey].
  ///
  /// Deleting the previous snapshot and re-inserting within a transaction
  /// prevents duplicates on refresh and drops rows that were removed on the
  /// server, while still being safe (the transaction rolls back on failure, so
  /// the working cache is never left half-written).
  Future<void> replaceSnapshot({
    required String cacheKey,
    required int userId,
    required String role,
    int? barangayId,
    String? municipality,
    required List<Map<String, dynamic>> rows,
    required DateTime updatedAt,
  }) async {
    final db = await database;
    final timestamp = updatedAt.toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        hotlinesTable,
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
      );

      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(hotlinesTable, {
          'cache_key': cacheKey,
          'id': int.tryParse(row['id'].toString()) ?? 0,
          'hotline_scope': row['hotline_scope']?.toString(),
          'barangay_id': _optionalInt(row['barangay_id']),
          'barangay_name': row['barangay_name']?.toString(),
          'office_name': row['office_name']?.toString(),
          'municipality': row['municipality']?.toString(),
          'category': row['category']?.toString(),
          'telephone_numbers': row['telephone_numbers']?.toString(),
          'cellphone_numbers': row['cellphone_numbers']?.toString(),
          'hotline_number': row['hotline_number']?.toString(),
          'remarks': row['remarks']?.toString(),
          'status': row['status']?.toString(),
          'updated_at': timestamp,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

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

  /// Returns the cached snapshot for [cacheKey] as maps shaped like the API
  /// rows (keys match the Flutter screen expectations). Empty when no cache
  /// exists for that scope.
  Future<List<Map<String, dynamic>>> getSnapshot(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      hotlinesTable,
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
    );
    return rows.map((row) {
      return Map<String, dynamic>.from(row)
        ..remove('cache_key')
        ..remove('updated_at');
    }).toList();
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

  static int? _optionalInt(Object? value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}
