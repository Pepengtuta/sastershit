import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../constants/api_config.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'incident_service.dart';
import 'report_queue_repository.dart';

/// Function that POSTs the report body (with `client_uuid`) to
/// `create_incident.php`. Injectable for tests.
typedef ReportPoster = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

/// Uploads [media] evidence files (manifest entries `{path, name, size, ext,
/// type}`) to the server for the given incident. Injectable for tests.
typedef ReportMediaUploader = Future<Map<String, dynamic>> Function({
  required int incidentId,
  required int uploadedBy,
  required List<Map<String, dynamic>> media,
});

/// Returns the attachment list already saved for an incident (used to skip
/// files that were uploaded before a lost response). Injectable for tests.
typedef ReportAttachmentListFetcher =
    Future<List<Map<String, dynamic>>> Function(int incidentId);

/// Sends queued offline reports to the server for the current signed-in user.
///
/// Design rules from the offline reports brief:
/// - The SQLite cache is always the source of truth; the network only decides
///   whether a send succeeds.
/// - A report is only ever sent with the SAME `client_uuid` (the idempotency
///   key). Retries never generate a new UUID.
/// - The sync loop is single-flight: concurrent triggers (submit, connectivity
///   restore, app resume, manual retry) share one in-flight sync and never run
///   two processes at the same time.
/// - Connection failures / timeouts keep the row and return it to `queued`;
///   server rejections move it to `failed`. Rows are never deleted.
/// - Everything is scoped by `user_id`, so account switching never leaks rows.
class OfflineReportSync {
  OfflineReportSync({
    ReportQueueRepository? repository,
    ReportPoster? poster,
    ReportMediaUploader? mediaUploader,
    ReportAttachmentListFetcher? attachmentListFetcher,
    List<Duration>? retryDelays,
  }) : _repository = repository ?? ReportQueueRepository.instance,
       _poster = poster ?? _defaultPoster,
       _mediaUploader = mediaUploader ?? _defaultMediaUploader,
       _attachmentListFetcher =
           attachmentListFetcher ?? _defaultAttachmentListFetcher,
       _retryDelays =
           retryDelays ?? const [
             Duration(seconds: 5),
             Duration(seconds: 10),
             Duration(seconds: 20),
             Duration(seconds: 30),
             Duration(minutes: 1),
           ];

  static OfflineReportSync instance = OfflineReportSync();

  final ReportQueueRepository _repository;
  final ReportPoster _poster;
  final ReportMediaUploader _mediaUploader;
  final ReportAttachmentListFetcher _attachmentListFetcher;

  /// Backoff schedule for silently re-sending queued reports after a transient
  /// failure. Injectable (and trimmable) for tests.
  final List<Duration> _retryDelays;

  Future<void>? _runningSync;
  Timer? _retryTimer;
  int _backoffIndex = 0;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  bool _initialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Fires after every queue status change so the UI can refresh.
  Stream<void> get changes => _changes.stream;

  static Future<Map<String, dynamic>> _defaultPoster(
    Map<String, dynamic> body,
  ) {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/create_incident.php',
      body: body,
    );
  }

  static Future<Map<String, dynamic>> _defaultMediaUploader({
    required int incidentId,
    required int uploadedBy,
    required List<Map<String, dynamic>> media,
  }) {
    final files = media
        .map((item) => item['path']?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .map(XFile.new)
        .toList();
    if (files.isEmpty) {
      return Future.value({
        'success': true,
        'message': 'No evidence to upload.',
        'data': [],
      });
    }
    return IncidentService.uploadEvidence(
      incidentId: incidentId,
      uploadedBy: uploadedBy,
      files: files,
    );
  }

  static Future<List<Map<String, dynamic>>> _defaultAttachmentListFetcher(
    int incidentId,
  ) async {
    final result = await IncidentService.getReportAttachments(
      reportId: incidentId,
    );
    final raw = result['data'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  /// Starts listening for connectivity restore and kicks off a sync for the
  /// current session. Safe to call more than once.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        syncForCurrentUser();
      }
    });
    syncForCurrentUser();
  }

  void dispose() {
    _cancelRetry();
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Syncs every pending row for the currently signed-in user (a no-op when
  /// there is no session).
  Future<void> syncForCurrentUser() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    await ensureSyncedForUser(userId);
  }

  /// Single-flight sync. If a sync is already running, callers await the same
  /// future instead of starting a second process.
  Future<void> ensureSyncedForUser(int userId) {
    final running = _runningSync;
    if (running != null) return running;

    final future = _runSyncLoop(userId);
    _runningSync = future;
    future.whenComplete(() {
      if (identical(_runningSync, future)) _runningSync = null;
    });
    return future;
  }

  /// Re-queues a single report (typically a `failed` report) and syncs.
  Future<void> retryRecord(int id) async {
    final record = await _repository.getById(id);
    if (record == null) return;
    await _repository.markQueued(id);
    await ensureSyncedForUser(record.userId);
  }

  Future<void> _runSyncLoop(int userId) async {
    final candidates = await _repository.getPendingForUser(userId);
    for (final record in candidates) {
      await _repository.markSending(record.id);
      _notify();

      final outcome = await _sendOnce(record);

      switch (outcome.status) {
        case ReportQueueStatus.sent:
          await _repository.markSent(
            record.id,
            incidentId: outcome.incidentId ?? 0,
          );
          _cleanupMediaFolder(record);
          break;
        case ReportQueueStatus.failed:
          await _repository.markFailed(
            record.id,
            outcome.errorMessage ?? 'Failed to send report.',
          );
          break;
        default:
          await _repository.markQueued(
            record.id,
            errorMessage: outcome.errorMessage,
          );
      }
      _notify();
    }
    _notify();

    // Any row still waiting (transient network failure) re-arms the silent
    // backoff retry; once nothing is pending the timer is cancelled. Failed
    // rows are never pending, so server rejections stay manual.
    final remaining = await _repository.getPendingForUser(userId);
    if (remaining.isNotEmpty) {
      _scheduleRetry(userId);
    } else {
      _cancelRetry();
    }
  }

  /// Schedules the next capped retry attempt for [userId]'s queued reports.
  /// Single timer at a time; a running sync never overlaps the next attempt
  /// because the timer re-enters [ensureSyncedForUser] (single-flight).
  void _scheduleRetry(int userId) {
    if (_retryTimer != null) return;
    final cap = _retryDelays.length - 1;
    final index = _backoffIndex > cap ? cap : _backoffIndex;
    _backoffIndex = index + 1;
    _retryTimer = Timer(_retryDelays[index], () {
      _retryTimer = null;
      unawaited(ensureSyncedForUser(userId));
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _backoffIndex = 0;
  }

  Future<_SyncOutcome> _sendOnce(QueuedReport record) async {
    if (!await _hasNetwork()) {
      return const _SyncOutcome(
        ReportQueueStatus.queued,
        errorMessage: 'No internet connection.',
      );
    }

    final body = {
      ...record.payload,
      'client_uuid': record.clientUuid,
    };

    try {
      final result = await _poster(body);
      if (result['success'] == true) {
        final incidentId = int.tryParse(
          result['data']?['incident_id']?.toString() ?? '',
        );
        if (incidentId != null && incidentId > 0) {
          if (record.mediaFiles.isNotEmpty) {
            final mediaOutcome = await _uploadMedia(record, incidentId);
            if (mediaOutcome.status != ReportQueueStatus.sent) {
              return mediaOutcome;
            }
          }
          return _SyncOutcome(ReportQueueStatus.sent, incidentId: incidentId);
        }
        return const _SyncOutcome(
          ReportQueueStatus.failed,
          errorMessage: 'Server did not return an incident id.',
        );
      }

      final message = result['message']?.toString() ?? 'Failed to send report.';
      final transient = ApiService.isConnectionFailure(message: message);
      if (transient) {
        return _SyncOutcome(ReportQueueStatus.queued, errorMessage: message);
      }
      return _SyncOutcome(ReportQueueStatus.failed, errorMessage: message);
    } catch (error) {
      // Lost response / socket error: keep the row queued, the retry reuses
      // the same client_uuid so the server resolves it idempotently.
      return _SyncOutcome(
        ReportQueueStatus.queued,
        errorMessage: 'Connection failed: $error',
      );
    }
  }

  /// Phase two of an offline submit: upload the report's evidence files to the
  /// server once the incident exists.
  ///
  /// Files already on the server (checked against the incident's attachment
  /// list) are skipped so a retry after a lost response never duplicates them.
  /// Connection failures keep the row queued (backoff retries it); a definitive
  /// server rejection moves it to `failed` (manual retry) so the report never
  /// spins forever on a rejection it can not fix. Individual files that
  /// disappeared locally are skipped and do not block the report.
  Future<_SyncOutcome> _uploadMedia(
    QueuedReport record,
    int incidentId,
  ) async {
    if (!await _hasNetwork()) {
      return const _SyncOutcome(
        ReportQueueStatus.queued,
        errorMessage: 'No internet connection.',
      );
    }

    final alreadyUploaded = <String>{};
    try {
      final existing = await _attachmentListFetcher(incidentId);
      for (final row in existing) {
        final key = _serverMediaKey(row);
        if (key != null) alreadyUploaded.add(key);
      }
    } catch (_) {
      // Failed pre-check means no safe dedup; a best-effort upload still runs
      // and the result decides the outcome.
    }

    final toUpload = <Map<String, dynamic>>[];
    for (final item in record.mediaFiles) {
      final path = item['path']?.toString() ?? '';
      if (path.isEmpty || !File(path).existsSync()) {
        continue;
      }
      final key = _mediaKey(item);
      if (key != null && alreadyUploaded.contains(key)) continue;
      toUpload.add(item);
    }

    // Nothing left to upload: the report is considered fully synced. Already-
    // uploaded files need no action; files missing locally were skipped.
    if (toUpload.isEmpty) {
      return const _SyncOutcome(ReportQueueStatus.sent);
    }

    try {
      final result = await _mediaUploader(
        incidentId: incidentId,
        uploadedBy: record.userId,
        media: toUpload,
      );
      if (result['success'] == true) {
        return const _SyncOutcome(ReportQueueStatus.sent);
      }
      final message = result['message']?.toString() ?? 'Evidence upload failed.';
      final transient = ApiService.isConnectionFailure(message: message);
      if (transient) {
        return _SyncOutcome(ReportQueueStatus.queued, errorMessage: message);
      }
      return _SyncOutcome(ReportQueueStatus.failed, errorMessage: message);
    } catch (error) {
      return _SyncOutcome(
        ReportQueueStatus.queued,
        errorMessage: 'Connection failed: $error',
      );
    }
  }

  /// Dedup key for a local media manifest entry.
  static String? _mediaKey(Map<String, dynamic> item) {
    final name = item['name']?.toString().trim().toLowerCase() ?? '';
    final size = item['size']?.toString() ?? '';
    final type = item['type']?.toString().trim().toLowerCase() ?? '';
    if (name.isEmpty || size.isEmpty || type.isEmpty) return null;
    return '$name|$size|$type';
  }

  /// Dedup key derived from a server attachment row (mirrors [_mediaKey]).
  static String? _serverMediaKey(Map<String, dynamic> row) {
    var name = row['file_name']?.toString().trim().toLowerCase() ?? '';
    if (name.isEmpty) {
      final path = row['file_path']?.toString().trim() ?? '';
      if (path.isNotEmpty) name = path.split('/').last.toLowerCase();
    }
    final size = row['file_size']?.toString() ?? '';
    var type = row['file_type']?.toString().trim().toLowerCase() ?? '';
    if (type.isEmpty) {
      type = row['type']?.toString().trim().toLowerCase() ?? '';
    }
    if (name.isEmpty || size.isEmpty || type.isEmpty) return null;
    return '$name|$size|$type';
  }

  /// Deletes the local media folder for a fully-synced report. Only removes it
  /// when the folder sits under `<app>/saster_media/<clientUuid>`, so a corrupt
  /// manifest can never delete unrelated files.
  void _cleanupMediaFolder(QueuedReport record) {
    if (record.mediaFiles.isEmpty) return;
    try {
      String? folder;
      for (final item in record.mediaFiles) {
        final path = item['path']?.toString() ?? '';
        if (path.isEmpty) continue;
        final dir = p.dirname(path);
        if (p.basename(dir) == record.clientUuid &&
            p.basename(p.dirname(dir)) == 'saster_media') {
          folder = dir;
          break;
        }
      }
      if (folder != null) {
        final directory = Directory(folder);
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      }
    } catch (_) {
      // Best-effort: leftover media is harmless.
    }
  }

  static Future<bool> _hasNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}

class _SyncOutcome {
  const _SyncOutcome(this.status, {this.incidentId, this.errorMessage});

  final String status;
  final int? incidentId;
  final String? errorMessage;
}