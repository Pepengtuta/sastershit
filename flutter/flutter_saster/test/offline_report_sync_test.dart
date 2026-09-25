import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/services/offline_report_sync.dart';
import 'package:flutter_saster/services/report_queue_database.dart';
import 'package:flutter_saster/services/report_queue_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDownAll(() async {
    await databaseFactory.deleteDatabase('test_sync_success.db');
    await databaseFactory.deleteDatabase('test_sync_transient.db');
    await databaseFactory.deleteDatabase('test_sync_server_error.db');
    await databaseFactory.deleteDatabase('test_sync_retry.db');
    await databaseFactory.deleteDatabase('test_sync_isolation.db');
    await databaseFactory.deleteDatabase('test_sync_backoff.db');
    await databaseFactory.deleteDatabase('test_sync_no_auto_failed.db');
    await databaseFactory.deleteDatabase('test_sync_media_missing.db');
    await databaseFactory.deleteDatabase('test_sync_media_rejected.db');
    await databaseFactory.deleteDatabase('test_sync_media_retry.db');
    await databaseFactory.deleteDatabase('test_sync_media_upload.db');
    await databaseFactory.deleteDatabase('test_sync_migration.db');
  });

  Map<String, dynamic> postBody() => {
    'disaster_type': 'Flood',
    'description': 'Flooded street.',
    'affected_people': 12,
  };

  group('OfflineReportSync decision logic', () {
    test('success marks the report sent with incident_id + synced_at', () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_success.db');
      final repo = ReportQueueRepository(database: db);
      final calls = <Map<String, dynamic>>[];
      final sync = OfflineReportSync(
        repository: repo,
        poster: (body) async {
          calls.add(body);
          return {'success': true, 'data': {'incident_id': 88}};
        },
      );

      final id = await repo.enqueue(
        userId: 1,
        barangayId: 3,
        clientUuid: 'uuid-sent',
        payload: postBody(),
      );

      await sync.ensureSyncedForUser(1);

      final record = await repo.getById(id);
      expect(record!.status, ReportQueueStatus.sent);
      expect(record.incidentId, 88);
      expect(record.syncedAt, isNotNull);
      expect(calls.single['client_uuid'], 'uuid-sent');
    });

    test('connection failure keeps the row queued and reuses the UUID', () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_transient.db');
      final repo = ReportQueueRepository(database: db);
      final calls = <Map<String, dynamic>>[];
      final sync = OfflineReportSync(
        repository: repo,
        poster: (body) async {
          calls.add(body);
          throw Exception('Connection failed: timed out');
        },
      );

      final id = await repo.enqueue(
        userId: 1,
        clientUuid: 'uuid-transient',
        payload: postBody(),
      );

      await sync.ensureSyncedForUser(1);

      final record = await repo.getById(id);
      expect(record!.status, ReportQueueStatus.queued);
      expect(record.incidentId, isNull);
      expect(calls.single['client_uuid'], 'uuid-transient');
    });

    test('server rejection moves the report to failed, never deletes it', () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_server_error.db');
      final repo = ReportQueueRepository(database: db);
      final sync = OfflineReportSync(
        repository: repo,
        poster: (_) async => {
          'success': false,
          'message': 'Barangay id is invalid.',
        },
      );

      final id = await repo.enqueue(
        userId: 1,
        clientUuid: 'uuid-server-error',
        payload: postBody(),
      );

      await sync.ensureSyncedForUser(1);

      final record = await repo.getById(id);
      expect(record!.status, ReportQueueStatus.failed);
      expect(record.clientUuid, 'uuid-server-error');
      expect(record.errorMessage, 'Barangay id is invalid.');
    });

    test('lost response then retry sends the same UUID and resolves idempotently', () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_retry.db');
      final repo = ReportQueueRepository(database: db);
      final uuids = <String>[];
      var attempt = 0;
      final sync = OfflineReportSync(
        repository: repo,
        poster: (body) async {
          attempt++;
          uuids.add(body['client_uuid'] as String);
          if (attempt == 1) {
            throw Exception('Connection failed: no response');
          }
          return {'success': true, 'data': {'incident_id': 99}};
        },
      );

      final id = await repo.enqueue(
        userId: 1,
        clientUuid: 'uuid-lost-response',
        payload: postBody(),
      );

      await sync.ensureSyncedForUser(1);
      expect((await repo.getById(id))!.status, ReportQueueStatus.queued);

      // Connectivity restored / manual retry: same UUID, new attempt.
      await sync.ensureSyncedForUser(1);

      final record = await repo.getById(id);
      expect(record!.status, ReportQueueStatus.sent);
      expect(record.incidentId, 99);
      expect(record.clientUuid, 'uuid-lost-response');
      expect(uuids, hasLength(2));
      expect(uuids[0], uuids[1]);
      expect(uuids[0], 'uuid-lost-response');
    });

    test('syncing for one user never sends another users reports', () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_isolation.db');
      final repo = ReportQueueRepository(database: db);
      var sentCount = 0;
      final sync = OfflineReportSync(
        repository: repo,
        poster: (_) async {
          sentCount++;
          return {'success': true, 'data': {'incident_id': 1}};
        },
      );

      await repo.enqueue(userId: 1, clientUuid: 'uuid-user1', payload: postBody());
      await repo.enqueue(userId: 2, clientUuid: 'uuid-user2', payload: postBody());

      await sync.ensureSyncedForUser(1);

      expect(sentCount, 1);
      expect((await repo.getByUuid('uuid-user1'))!.status, ReportQueueStatus.sent);
      expect((await repo.getByUuid('uuid-user2'))!.status, ReportQueueStatus.queued);
    });

    test('transient failures auto-retry in the background until the report '
        'sends', () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_backoff.db');
      final repo = ReportQueueRepository(database: db);
      var attempt = 0;
      final sync = OfflineReportSync(
        repository: repo,
        retryDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 10),
        ],
        poster: (body) async {
          attempt++;
          if (attempt <= 2) throw Exception('Connection failed: timed out');
          return {'success': true, 'data': {'incident_id': 123}};
        },
      );

      final id = await repo.enqueue(
        userId: 1,
        clientUuid: 'uuid-backoff',
        payload: postBody(),
      );

      // First sync fails transiently and leaves the row queued.
      await sync.ensureSyncedForUser(1);
      expect((await repo.getById(id))!.status, ReportQueueStatus.queued);

      // The timer-driven retries run on their own; poll until sent.
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while ((await repo.getById(id))!.status != ReportQueueStatus.sent &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      final record = await repo.getById(id);
      expect(record!.status, ReportQueueStatus.sent);
      expect(record.incidentId, 123);
      expect(attempt, greaterThanOrEqualTo(3));
      expect(record.clientUuid, 'uuid-backoff');
      sync.dispose();
    });

    test('server-rejected reports never auto-retry', () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_no_auto_failed.db');
      final repo = ReportQueueRepository(database: db);
      var attempt = 0;
      final sync = OfflineReportSync(
        repository: repo,
        retryDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 10),
        ],
        poster: (_) async {
          attempt++;
          return {'success': false, 'message': 'Barangay id is invalid.'};
        },
      );

      final id = await repo.enqueue(
        userId: 1,
        clientUuid: 'uuid-failed',
        payload: postBody(),
      );

      await sync.ensureSyncedForUser(1);
      expect((await repo.getById(id))!.status, ReportQueueStatus.failed);

      // Give any (unwanted) retry timer time to fire.
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final record = await repo.getById(id);
      expect(record!.status, ReportQueueStatus.failed);
      expect(attempt, 1, reason: 'failed rows must stay manual');
      sync.dispose();
    });
  });

  group('OfflineReportSync media upload', () {
    test('evidence uploads after the report is created on the server', () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_media_upload.db');
      final repo = ReportQueueRepository(database: db);
      final temp = await Directory.systemTemp.createTemp('saster_test_upload');
      addTearDown(() => temp.delete(recursive: true));
      final photo = File(p.join(temp.path, '0_photo.jpg'))
        ..writeAsBytesSync(List.filled(1024, 1));
      final clip = File(p.join(temp.path, '0_clip.mp4'))
        ..writeAsBytesSync(List.filled(2048, 2));

      final mediaCalls = <String>[];
      final sync = OfflineReportSync(
        repository: repo,
        poster: (_) async => {'success': true, 'data': {'incident_id': 88}},
        attachmentListFetcher: (_) async => <Map<String, dynamic>>[],
        mediaUploader:
            ({required incidentId, required uploadedBy, required media}) async {
              mediaCalls.add('$incidentId|$uploadedBy|${media.length}');
              return {'success': true, 'message': 'ok', 'data': []};
            },
      );

      final id = await repo.enqueue(
        userId: 1,
        clientUuid: 'uuid-media',
        payload: postBody(),
        mediaFiles: [
          {
            'path': photo.path,
            'name': '0_photo.jpg',
            'size': 1024,
            'ext': 'jpg',
            'type': 'photo',
          },
          {
            'path': clip.path,
            'name': '0_clip.mp4',
            'size': 2048,
            'ext': 'mp4',
            'type': 'video',
          },
        ],
      );

      await sync.ensureSyncedForUser(1);

      final record = await repo.getById(id);
      expect(record!.status, ReportQueueStatus.sent);
      expect(record.incidentId, 88);
      expect(mediaCalls, ['88|1|2']);
    });

    test('retry after a lost upload skips files the server already saved',
        () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_media_retry.db');
      final repo = ReportQueueRepository(database: db);
      final temp = await Directory.systemTemp.createTemp('saster_test_retry');
      addTearDown(() => temp.delete(recursive: true));
      final saved = File(p.join(temp.path, '0_photo.jpg'))
        ..writeAsBytesSync(List.filled(1024, 1));
      final pending = File(p.join(temp.path, '0_clip.mp4'))
        ..writeAsBytesSync(List.filled(2048, 2));

      final uploads = <List<String>>[];
      var attempt = 0;
      final sync = OfflineReportSync(
        repository: repo,
        poster: (_) async => {'success': true, 'data': {'incident_id': 88}},
        attachmentListFetcher: (incidentId) async {
          return attempt >= 1
              ? [
                  {
                    'file_name': '0_photo.jpg',
                    'file_size': 1024,
                    'file_type': 'photo',
                  },
                ]
              : <Map<String, dynamic>>[];
        },
        mediaUploader:
            ({required incidentId, required uploadedBy, required media}) async {
              attempt++;
              uploads.add(media.map((m) => m['name'].toString()).toList());
              if (attempt == 1) {
                throw Exception('Connection failed: no response');
              }
              return {'success': true, 'message': 'ok', 'data': []};
            },
      );

      final id = await repo.enqueue(
        userId: 1,
        clientUuid: 'uuid-media-retry',
        payload: postBody(),
        mediaFiles: [
          {
            'path': saved.path,
            'name': '0_photo.jpg',
            'size': 1024,
            'ext': 'jpg',
            'type': 'photo',
          },
          {
            'path': pending.path,
            'name': '0_clip.mp4',
            'size': 2048,
            'ext': 'mp4',
            'type': 'video',
          },
        ],
      );

      await sync.ensureSyncedForUser(1);
      expect((await repo.getById(id))!.status, ReportQueueStatus.queued);

      await sync.ensureSyncedForUser(1);

      final record = await repo.getById(id);
      expect(record!.status, ReportQueueStatus.sent);
      expect(uploads, hasLength(2));
      expect(uploads[0], hasLength(2));
      expect(uploads[1], ['0_clip.mp4']);
    });

    test('definitive media rejection marks the report failed for manual retry',
        () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_media_rejected.db');
      final repo = ReportQueueRepository(database: db);
      final temp = await Directory.systemTemp.createTemp('saster_test_reject');
      addTearDown(() => temp.delete(recursive: true));
      final photo = File(p.join(temp.path, '0_photo.jpg'))
        ..writeAsBytesSync(List.filled(1024, 1));

      final sync = OfflineReportSync(
        repository: repo,
        poster: (_) async => {'success': true, 'data': {'incident_id': 88}},
        attachmentListFetcher: (_) async => <Map<String, dynamic>>[],
        mediaUploader:
            ({required incidentId, required uploadedBy, required media}) async {
              return {
                'success': false,
                'message': 'Maximum 5 photos per report.',
              };
            },
      );

      final id = await repo.enqueue(
        userId: 1,
        clientUuid: 'uuid-media-rejected',
        payload: postBody(),
        mediaFiles: [
          {
            'path': photo.path,
            'name': '0_photo.jpg',
            'size': 1024,
            'ext': 'jpg',
            'type': 'photo',
          },
        ],
      );

      await sync.ensureSyncedForUser(1);

      final record = await repo.getById(id);
      expect(record!.status, ReportQueueStatus.failed);
      expect(record.errorMessage, 'Maximum 5 photos per report.');
    });

    test('a media file that vanished locally is skipped and the report still '
        'sends', () async {
      final db = ReportQueueDatabase(dbName: 'test_sync_media_missing.db');
      final repo = ReportQueueRepository(database: db);
      var uploadCalls = 0;
      final sync = OfflineReportSync(
        repository: repo,
        poster: (_) async => {'success': true, 'data': {'incident_id': 88}},
        attachmentListFetcher: (_) async => <Map<String, dynamic>>[],
        mediaUploader:
            ({required incidentId, required uploadedBy, required media}) async {
              uploadCalls++;
              return {'success': true, 'message': 'ok', 'data': []};
            },
      );

      final id = await repo.enqueue(
        userId: 1,
        clientUuid: 'uuid-media-missing',
        payload: postBody(),
        mediaFiles: [
          {
            'path': p.join(Directory.systemTemp.path, 'does_not_exist.jpg'),
            'name': '0_photo.jpg',
            'size': 1024,
            'ext': 'jpg',
            'type': 'photo',
          },
        ],
      );

      await sync.ensureSyncedForUser(1);

      final record = await repo.getById(id);
      expect(record!.status, ReportQueueStatus.sent);
      expect(uploadCalls, 0);
    });
  });

  group('ReportQueueDatabase schema migration', () {
    test('existing v1 databases gain the media_files column', () async {
      final dbPath = p.join(await getDatabasesPath(), 'test_sync_migration.db');
      final legacy = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE queued_reports (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL,
              barangay_id INTEGER,
              client_uuid TEXT NOT NULL UNIQUE,
              payload TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'queued',
              incident_id INTEGER,
              error_message TEXT,
              created_at TEXT NOT NULL,
              synced_at TEXT
            )
          ''');
        },
      );
      await legacy.close();

      final db = ReportQueueDatabase(dbName: 'test_sync_migration.db');
      final handle = await db.database;
      final columns = await handle.rawQuery('PRAGMA table_info(queued_reports)');
      final names = columns.map((c) => c['name'].toString()).toList();
      expect(names, contains('media_files'));
      await handle.close();
    });
  });
}