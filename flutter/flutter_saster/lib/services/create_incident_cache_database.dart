import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite storage for the reference data the Create Incident form
/// needs before a report can be completed:
/// - the server's canonical active disaster types (id + name + is_natural)
/// - the evacuation center list for the acting barangay's scope
///
/// The evacuation center snapshot is stored as a JSON payload keyed by
/// (barangay_id, barangay_name) so cached data can never leak between
/// barangays. Disaster types are a single global snapshot because the
/// server returns the same active list to every user.
class CreateIncidentCacheDatabase {
  CreateIncidentCacheDatabase._();

  static final CreateIncidentCacheDatabase instance = CreateIncidentCacheDatabase._();

  static const String disasterTypesTable = 'cached_disaster_types';
  static const String evacCentersTable = 'cached_evacuation_centers';

  static const String _dbName = 'saster_incident_form_cache.db';
  static const int _dbVersion = 1;

  Future<Database>? _databaseFuture;

  /// Single-flight DB handle: the first caller opens the file and every
  /// concurrent caller (disaster types + evacuation centers both load on the
  /// Create Incident screen at the same time) waits on the SAME open instead
  /// of racing two connections for the same file.
  Future<Database> get database => _databaseFuture ??= _open();

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $disasterTypesTable (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            is_natural INTEGER NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $evacCentersTable (
            barangay_id INTEGER NOT NULL,
            barangay_name TEXT NOT NULL DEFAULT '',
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (barangay_id, barangay_name)
          )
        ''');
      },
    );
  }

  /// Atomically replaces the cached disaster types snapshot.
  Future<void> replaceDisasterTypes({
    required List<Map<String, dynamic>> rows,
    required DateTime updatedAt,
  }) async {
    final db = await database;
    final timestamp = updatedAt.toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(disasterTypesTable, where: '1 = 1');
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(disasterTypesTable, {
          'id': int.tryParse(row['id']?.toString() ?? '') ?? 0,
          'name': row['name']?.toString() ?? '',
          'is_natural': (row['is_natural'] ?? 1) == 1 ? 1 : 0,
          'updated_at': timestamp,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Returns the cached disaster types ordered by the server's id ordering.
  Future<List<Map<String, dynamic>>> getDisasterTypes() async {
    final db = await database;
    final rows = await db.query(
      disasterTypesTable,
      orderBy: 'id ASC',
    );
    return rows.map((row) {
      return Map<String, dynamic>.from(row)
        ..remove('updated_at');
    }).toList();
  }

  /// The last successful network update of the disaster types snapshot,
  /// or null if it was never fetched successfully.
  Future<DateTime?> getDisasterTypesLastUpdated() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT MAX(updated_at) AS updated_at FROM $disasterTypesTable',
    );
    final raw = rows.isEmpty ? null : rows.first['updated_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Atomically replaces the evacuation center snapshot for one barangay scope.
  Future<void> replaceEvacuationCenters({
    required int barangayId,
    required String barangayName,
    required List<Map<String, dynamic>> rows,
    required DateTime updatedAt,
  }) async {
    final db = await database;
    final timestamp = updatedAt.toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        evacCentersTable,
        where: 'barangay_id = ? AND barangay_name = ?',
        whereArgs: [barangayId, barangayName],
      );
      await txn.insert(evacCentersTable, {
        'barangay_id': barangayId,
        'barangay_name': barangayName,
        'payload': jsonEncode(rows),
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Returns the cached evacuation center rows for one barangay scope,
  /// shaped exactly like the API rows the form's dropdown expects.
  Future<List<Map<String, dynamic>>> getEvacuationCenters({
    required int barangayId,
    required String barangayName,
  }) async {
    final db = await database;
    final rows = await db.query(
      evacCentersTable,
      where: 'barangay_id = ? AND barangay_name = ?',
      whereArgs: [barangayId, barangayName],
      limit: 1,
    );
    if (rows.isEmpty) return [];
    final payload = rows.first['payload']?.toString();
    if (payload == null || payload.isEmpty) return [];
    final decoded = jsonDecode(payload);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// The last successful network update of the evacuation center snapshot
  /// for one barangay scope, or null if it was never fetched successfully.
  Future<DateTime?> getEvacuationCentersLastUpdated({
    required int barangayId,
    required String barangayName,
  }) async {
    final db = await database;
    final rows = await db.query(
      evacCentersTable,
      columns: ['updated_at'],
      where: 'barangay_id = ? AND barangay_name = ?',
      whereArgs: [barangayId, barangayName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['updated_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}