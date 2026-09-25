import 'dart:convert';

import 'report_queue_database.dart';

/// Local statuses for a queued report.
class ReportQueueStatus {
  ReportQueueStatus._();

  static const String queued = 'queued';
  static const String sending = 'sending';
  static const String sent = 'sent';
  static const String failed = 'failed';
}

/// One offline report submission waiting to reach the server.
class QueuedReport {
  const QueuedReport({
    required this.id,
    required this.userId,
    required this.barangayId,
    required this.clientUuid,
    required this.payload,
    required this.mediaFiles,
    required this.status,
    required this.incidentId,
    required this.errorMessage,
    required this.createdAt,
    required this.syncedAt,
  });

  factory QueuedReport.fromRow(Map<String, dynamic> row) {
    return QueuedReport(
      id: int.tryParse(row['id']?.toString() ?? '') ?? 0,
      userId: int.tryParse(row['user_id']?.toString() ?? '') ?? 0,
      barangayId: int.tryParse(row['barangay_id']?.toString() ?? ''),
      clientUuid: row['client_uuid']?.toString() ?? '',
      payload: _decodePayload(row['payload']),
      mediaFiles: _decodeMedia(row['media_files']),
      status: row['status']?.toString() ?? ReportQueueStatus.queued,
      incidentId: int.tryParse(row['incident_id']?.toString() ?? ''),
      errorMessage: row['error_message']?.toString(),
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      syncedAt: _optionalDate(row['synced_at']),
    );
  }

  final int id;
  final int userId;
  final int? barangayId;
  final String clientUuid;
  final Map<String, dynamic> payload;

  /// Local evidence files waiting to be uploaded after the report is created:
  /// each entry is `{path, name, size, ext, type}`.
  final List<Map<String, dynamic>> mediaFiles;
  final String status;
  final int? incidentId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? syncedAt;

  static Map<String, dynamic> _decodePayload(Object? raw) {
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw.toString());
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static List<Map<String, dynamic>> _decodeMedia(Object? raw) {
    if (raw == null) return const <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      // Malformed media metadata is ignored; the text report still syncs.
    }
    return const <Map<String, dynamic>>[];
  }

  static DateTime? _optionalDate(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }
}

/// Coordinates the queue database rows with the API sync loop.
class ReportQueueRepository {
  ReportQueueRepository({ReportQueueDatabase? database})
    : _database = database ?? ReportQueueDatabase();

  final ReportQueueDatabase _database;

  static ReportQueueRepository instance = ReportQueueRepository();

  Future<int> enqueue({
    required int userId,
    int? barangayId,
    required String clientUuid,
    required Map<String, dynamic> payload,
    List<Map<String, dynamic>> mediaFiles = const [],
  }) {
    return _database.enqueue(
      userId: userId,
      barangayId: barangayId,
      clientUuid: clientUuid,
      payload: jsonEncode(payload),
      mediaFiles: mediaFiles.isEmpty ? null : jsonEncode(mediaFiles),
      createdAt: DateTime.now(),
    );
  }

  Future<List<QueuedReport>> getForUser(int userId) async {
    final rows = await _database.getForUser(userId);
    return rows.map(QueuedReport.fromRow).toList();
  }

  Future<List<QueuedReport>> getPendingForUser(int userId) async {
    final rows = await _database.getPendingForUser(userId);
    return rows.map(QueuedReport.fromRow).toList();
  }

  Future<QueuedReport?> getById(int id) async {
    final row = await _database.getById(id);
    return row == null ? null : QueuedReport.fromRow(row);
  }

  Future<QueuedReport?> getByUuid(String clientUuid) async {
    final row = await _database.getByUuid(clientUuid);
    return row == null ? null : QueuedReport.fromRow(row);
  }

  Future<void> markSending(int id) {
    return _database.updateResult(id: id, status: ReportQueueStatus.sending);
  }

  Future<void> markQueued(int id, {String? errorMessage}) {
    return _database.updateResult(
      id: id,
      status: ReportQueueStatus.queued,
      errorMessage: errorMessage,
    );
  }

  Future<void> markSent(int id, {required int incidentId, DateTime? syncedAt}) {
    return _database.updateResult(
      id: id,
      status: ReportQueueStatus.sent,
      incidentId: incidentId,
      syncedAt: syncedAt ?? DateTime.now(),
    );
  }

  Future<void> markFailed(int id, String errorMessage) {
    return _database.updateResult(
      id: id,
      status: ReportQueueStatus.failed,
      errorMessage: errorMessage,
    );
  }
}