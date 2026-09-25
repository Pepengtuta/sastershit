import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/services/assistance_cache_database.dart';
import 'package:flutter_saster/services/assistance_repository.dart';

void main() {
  const dbName = 'test_assistance_repo.db';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDownAll(() async {
    await databaseFactory.deleteDatabase(dbName);
  });

  AssistanceCacheDatabase freshCache() => AssistanceCacheDatabase(dbName: dbName);

  Future<Map<String, dynamic>> okNeeds({required int evacCenterId}) async {
    return {
      'success': true,
      'data': {
        'evac_center_id': evacCenterId,
        'needs': [
          {'id': 1, 'item': 'Rice', 'quantity_needed': 50, 'quantity_received': 10},
        ],
      },
    };
  }

  Future<Map<String, dynamic>> failingNeeds({required int evacCenterId}) async {
    return {'success': false, 'message': 'No network'};
  }

  Future<Map<String, dynamic>> okBoard({String? municipality}) async {
    return {
      'success': true,
      'data': {
        'scope_label': municipality ?? 'All',
        'centers': [
          {'id': 1, 'center_name': 'Aklan State University'},
        ],
      },
    };
  }

  Future<Map<String, dynamic>> failingBoard({String? municipality}) async {
    return {'success': false, 'message': 'No network'};
  }

  group('cache keys', () {
    test('center-needs keys are isolated per center', () {
      final a = AssistanceRepository.buildNeedsCacheKey(userId: 1, evacCenterId: 5);
      final b = AssistanceRepository.buildNeedsCacheKey(userId: 1, evacCenterId: 6);
      expect(a, isNot(b));
    });

    test('board keys are isolated per user and municipality scope', () {
      final a = AssistanceRepository.buildBoardCacheKey(
        userId: 1,
        role: 'pho',
        municipality: 'Kalibo',
      );
      final b = AssistanceRepository.buildBoardCacheKey(
        userId: 1,
        role: 'pho',
        municipality: 'Ibajay',
      );
      final c = AssistanceRepository.buildBoardCacheKey(
        userId: 2,
        role: 'pho',
        municipality: 'Kalibo',
      );
      expect(a, isNot(b));
      expect(a, isNot(c));
    });
  });

  group('center needs', () {
    test('refresh success stores the document for offline reads', () async {
      final repo = AssistanceRepository(
        cache: freshCache(),
        needsFetcher: okNeeds,
      );

      final refreshed = await repo.refreshCenterNeeds(userId: 1, evacCenterId: 5);
      expect(refreshed.offline, isFalse);
      expect(refreshed.hasCache, isTrue);
      expect(refreshed.data?['needs'], hasLength(1));
      expect(refreshed.lastUpdated, isNotNull);

      final cached = await repo.getCachedCenterNeeds(userId: 1, evacCenterId: 5);
      expect(cached.hasCache, isTrue);
      expect((cached.data?['needs'] as List).single['item'], 'Rice');
    });

    test('a failed refresh preserves the previous needs document', () async {
      final db = freshCache();
      final good = AssistanceRepository(cache: db, needsFetcher: okNeeds);
      await good.refreshCenterNeeds(userId: 1, evacCenterId: 5);

      final bad = AssistanceRepository(cache: db, needsFetcher: failingNeeds);
      final failed = await bad.refreshCenterNeeds(userId: 1, evacCenterId: 5);
      expect(failed.offline, isTrue);

      final cached = await bad.getCachedCenterNeeds(userId: 1, evacCenterId: 5);
      expect(cached.hasCache, isTrue);
      expect(cached.data?['needs'], hasLength(1));
    });
  });

  group('assistance board', () {
    test('refresh success stores the document for offline reads', () async {
      final repo = AssistanceRepository(
        cache: freshCache(),
        boardFetcher: okBoard,
      );

      final refreshed = await repo.refreshBoard(
        userId: 1,
        role: 'pho',
        municipality: 'Kalibo',
      );
      expect(refreshed.offline, isFalse);
      expect(refreshed.hasCache, isTrue);
      expect(refreshed.data?['centers'], hasLength(1));

      final cached = await repo.getCachedBoard(
        userId: 1,
        role: 'pho',
        municipality: 'Kalibo',
      );
      expect(cached.hasCache, isTrue);
      expect((cached.data?['centers'] as List).single['center_name'],
          'Aklan State University');
    });

    test('a failed refresh preserves the previous board document', () async {
      final db = freshCache();
      final good = AssistanceRepository(cache: db, boardFetcher: okBoard);
      await good.refreshBoard(userId: 1, role: 'pho', municipality: 'Kalibo');

      final bad = AssistanceRepository(cache: db, boardFetcher: failingBoard);
      final failed = await bad.refreshBoard(
        userId: 1,
        role: 'pho',
        municipality: 'Kalibo',
      );
      expect(failed.offline, isTrue);

      final cached = await bad.getCachedBoard(
        userId: 1,
        role: 'pho',
        municipality: 'Kalibo',
      );
      expect(cached.hasCache, isTrue);
      expect(cached.data?['centers'], hasLength(1));
    });

    test('one municipality scope never sees another scope cache', () async {
      final repo = AssistanceRepository(cache: freshCache(), boardFetcher: okBoard);
      await repo.refreshBoard(userId: 1, role: 'pho', municipality: 'Kalibo');

      final other = await repo.getCachedBoard(
        userId: 1,
        role: 'pho',
        municipality: 'Ibajay',
      );
      expect(other.hasCache, isFalse);
    });
  });
}
