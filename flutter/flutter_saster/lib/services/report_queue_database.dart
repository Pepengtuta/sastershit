import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite queue for incident reports awaiting synchronization.
///
/// Every report saved while offline (or saved queue-first, then sent) lives
/// here until the server confirms it. Rows are never deleted after a failure;
/// retries reuse the same `client_uuid` so the server resolves duplicate
/// submissions idempotently. All queries are scoped by `user_id`, so a
/// different user signing in on the same device can never see or send another
/// user's reports.
class ReportQueueDatabase {
  ReportQueueDatabase({this._dbName = 'saster_report_queue.db'});

  static const int _dbVersion = 2;

  static const String queuedReportsTable = 'queued_reports';

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
          CREATE TABLE $queuedReportsTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            barangay_id INTEGER,
            client_uuid TEXT NOT NULL UNIQUE,
            payload TEXT NOT NULL,
            media_files TEXT,
            status TEXT NOT NULL DEFAULT 'queued',
            incident_id INTEGER,
            error_message TEXT,
            created_at TEXT NOT NULL,
            synced_at TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_queued_reports_user_status
          ON $queuedReportsTable (user_id, status)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $queuedReportsTable ADD COLUMN media_files TEXT',
          );
        }
      },
    );
  }

  Future<int> enqueue({
    required int userId,
    int? barangayId,
    required String clientUuid,
    required String payload,
    String? mediaFiles,
    required DateTime createdAt,
  }) async {
    final db = await database;
    return db.insert(queuedReportsTable, {
      'user_id': userId,
      'barangay_id': barangayId,
      'client_uuid': clientUuid,
      'payload': payload,
      'media_files': mediaFiles,
      'status': 'queued',
      'created_at': createdAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> getForUser(int userId) async {
    final db = await database;
    return db.query(
      queuedReportsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  /// Rows still waiting to reach the server for one user: queued or sending.
  Future<List<Map<String, dynamic>>> getPendingForUser(int userId) async {
    final db = await database;
    return db.query(
      queuedReportsTable,
      where: 'user_id = ? AND status IN (?, ?)',
      whereArgs: [userId, 'queued', 'sending'],
      orderBy: 'created_at ASC',
    );
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await database;
    final rows = await db.query(
      queuedReportsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getByUuid(String clientUuid) async {
    final db = await database;
    final rows = await db.query(
      queuedReportsTable,
      where: 'client_uuid = ?',
      whereArgs: [clientUuid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateResult({
    required int id,
    required String status,
    int? incidentId,
    String? errorMessage,
    DateTime? syncedAt,
  }) async {
    final db = await database;
    await db.update(
      queuedReportsTable,
      {
        'status': status,
        'incident_id': ?incidentId,
        'synced_at': ?syncedAt?.toUtc().toIso8601String(),
        'error_message': ?errorMessage,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}