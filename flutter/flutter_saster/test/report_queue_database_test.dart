import 'package:flutter_test/flutter_test.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/services/report_queue_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDownAll(() async {
    await databaseFactory.deleteDatabase('test_queue_roundtrip.db');
    await databaseFactory.deleteDatabase('test_queue_isolation.db');
    await databaseFactory.deleteDatabase('test_queue_duplicate.db');
  });

  group('ReportQueueDatabase', () {
    test('round-trips enqueue/getByUuid/updateResult', () async {
      final db = ReportQueueDatabase(dbName: 'test_queue_roundtrip.db');
      final id = await db.enqueue(
        userId: 1,
        barangayId: 3,
        clientUuid: 'uuid-1',
        payload: '{"disaster_type":"Flood"}',
        createdAt: DateTime(2026, 1, 1, 8, 0),
      );

      final row = await db.getByUuid('uuid-1');
      expect(row, isNotNull);
      expect(row!['user_id'], 1);
      expect(row['status'], 'queued');
      expect(row['payload'], contains('Flood'));

      await db.updateResult(
        id: id,
        status: 'sent',
        incidentId: 77,
        syncedAt: DateTime(2026, 1, 1, 9, 0),
      );

      final sent = await db.getById(id);
      expect(sent!['status'], 'sent');
      expect(sent['incident_id'], 77);
      expect(sent['synced_at'], isNotNull);
    });

    test('rows are isolated per user and per pending status', () async {
      final db = ReportQueueDatabase(dbName: 'test_queue_isolation.db');
      await db.enqueue(
        userId: 1,
        clientUuid: 'uuid-a',
        payload: '{}',
        createdAt: DateTime(2026, 1, 1, 8, 0),
      );
      await db.enqueue(
        userId: 2,
        clientUuid: 'uuid-b',
        payload: '{}',
        createdAt: DateTime(2026, 1, 1, 8, 1),
      );

      expect(await db.getForUser(1), hasLength(1));
      expect(await db.getPendingForUser(1), hasLength(1));
      expect(await db.getPendingForUser(2), hasLength(1));
      expect(await db.getByUuid('uuid-a'), isNotNull);
      expect(await db.getByUuid('uuid-b'), isNotNull);

      // Once sent, a row no longer shows up as pending.
      final idA = (await db.getByUuid('uuid-a'))!['id'] as int;
      await db.updateResult(id: idA, status: 'sent', incidentId: 1);
      expect(await db.getPendingForUser(1), isEmpty);
    });

    test('enqueue with a duplicate client_uuid is ignored', () async {
      final db = ReportQueueDatabase(dbName: 'test_queue_duplicate.db');
      await db.enqueue(
        userId: 1,
        clientUuid: 'uuid-x',
        payload: '{"v":1}',
        createdAt: DateTime(2026, 1, 1, 8, 0),
      );
      await db.enqueue(
        userId: 1,
        clientUuid: 'uuid-x',
        payload: '{"v":2}',
        createdAt: DateTime(2026, 1, 1, 8, 1),
      );

      expect(await db.getForUser(1), hasLength(1));
      expect((await db.getByUuid('uuid-x'))!['payload'], '{"v":1}');
    });
  });
}