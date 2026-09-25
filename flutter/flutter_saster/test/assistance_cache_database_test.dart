import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/services/assistance_cache_database.dart';

void main() {
  const dbName = 'test_assistance_cache.db';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDownAll(() async {
    await databaseFactory.deleteDatabase(dbName);
  });

  group('AssistanceCacheDatabase', () {
    test('round-trips a list snapshot and its last-updated time', () async {
      final db = AssistanceCacheDatabase(dbName: dbName);
      final now = DateTime(2026, 9, 21, 10, 30);
      await db.replaceSnapshot(
        cacheKey: 'centers|u1',
        dataset: 'evacuation_centers',
        userId: 1,
        role: 'barangay',
        payload: [
          {'id': 1, 'center_name': 'Aklan State University'},
        ],
        updatedAt: now,
      );

      final snap = await db.getSnapshot('centers|u1');
      expect(snap, isA<List>());
      expect((snap as List).single['center_name'], 'Aklan State University');

      final updated = await db.getLastUpdated('centers|u1');
      expect(updated, isNotNull);
      expect(updated!.toUtc(), now.toUtc());
    });

    test('round-trips a map document snapshot', () async {
      final db = AssistanceCacheDatabase(dbName: dbName);
      await db.replaceSnapshot(
        cacheKey: 'board|u1',
        dataset: 'assistance_board',
        userId: 1,
        role: 'pho',
        payload: {
          'scope_label': 'Kalibo',
          'centers': [],
        },
        updatedAt: DateTime(2026, 1, 1),
      );

      final snap = await db.getSnapshot('board|u1') as Map;
      expect(snap['scope_label'], 'Kalibo');
    });

    test('replacing a snapshot never duplicates rows', () async {
      final db = AssistanceCacheDatabase(dbName: dbName);
      await db.replaceSnapshot(
        cacheKey: 'replace-me',
        dataset: 'evacuation_centers',
        userId: 1,
        payload: [
          {'id': 1},
        ],
        updatedAt: DateTime(2026, 1, 1),
      );
      await db.replaceSnapshot(
        cacheKey: 'replace-me',
        dataset: 'evacuation_centers',
        userId: 1,
        payload: [
          {'id': 2},
        ],
        updatedAt: DateTime(2026, 1, 2),
      );

      final snap = await db.getSnapshot('replace-me') as List;
      expect(snap, hasLength(1));
      expect(snap.single['id'], 2);
    });

    test('scopes are isolated by cache key', () async {
      final db = AssistanceCacheDatabase(dbName: dbName);
      await db.replaceSnapshot(
        cacheKey: 'scope-a',
        dataset: 'evacuation_centers',
        userId: 1,
        payload: [
          {'id': 1},
        ],
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(await db.getSnapshot('scope-b'), isNull);
      expect(await db.getLastUpdated('scope-b'), isNull);
    });
  });
}
