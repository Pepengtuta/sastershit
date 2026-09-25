import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/services/assistance_cache_database.dart';
import 'package:flutter_saster/services/evacuation_center_repository.dart';

void main() {
  const dbName = 'test_evac_center_repo.db';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDownAll(() async {
    await databaseFactory.deleteDatabase(dbName);
  });

  AssistanceCacheDatabase freshCache() => AssistanceCacheDatabase(dbName: dbName);

  Future<Map<String, dynamic>> okCenters({
    required String role,
    int? barangayId,
    String? barangayName,
    String? municipality,
  }) async {
    return {
      'success': true,
      'data': [
        {
          'id': 1,
          'center_name': 'Aklan State University',
          'barangay': 'Andagao',
          'status': 'Open',
          'center_type': 'Evacuation Center',
          'capacity': 100,
          'current_evacuees': 20,
          'municipality': municipality ?? 'Kalibo',
        },
      ],
    };
  }

  Future<Map<String, dynamic>> failingCenters({
    required String role,
    int? barangayId,
    String? barangayName,
    String? municipality,
  }) async {
    return {'success': false, 'message': 'No network'};
  }

  group('buildCacheKey', () {
    test('isolates users and scopes from one another', () {
      final a = EvacuationCenterRepository.buildCacheKey(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
      );
      final b = EvacuationCenterRepository.buildCacheKey(
        userId: 2,
        role: 'barangay',
        barangayId: 5,
      );
      final c = EvacuationCenterRepository.buildCacheKey(
        userId: 1,
        role: 'pho',
        municipality: 'Kalibo',
      );
      final d = EvacuationCenterRepository.buildCacheKey(
        userId: 1,
        role: 'pho',
        municipality: 'Ibajay',
      );

      expect(a, isNot(b));
      expect(c, isNot(d));
      expect(a, isNot(c));
    });
  });

  group('filterLocally', () {
    final rows = [
      {
        'id': 1,
        'center_name': 'Aklan State University',
        'barangay': 'Andagao',
        'status': 'Open',
        'center_type': 'Evacuation Center',
      },
      {
        'id': 2,
        'center_name': 'Ibajay Gym',
        'barangay': 'Poblacion',
        'status': 'Full',
        'center_type': 'Gym',
      },
    ];

    test('empty search returns every row', () {
      expect(EvacuationCenterRepository.filterLocally(rows, search: ''), hasLength(2));
    });

    test('matches name, barangay, status and type case-insensitively', () {
      expect(
        EvacuationCenterRepository.filterLocally(rows, search: 'aklan').single['id'],
        1,
      );
      expect(
        EvacuationCenterRepository.filterLocally(rows, search: 'poblacion').single['id'],
        2,
      );
      expect(
        EvacuationCenterRepository.filterLocally(rows, search: 'full').single['id'],
        2,
      );
      expect(
        EvacuationCenterRepository.filterLocally(rows, search: 'gym').single['id'],
        2,
      );
      expect(EvacuationCenterRepository.filterLocally(rows, search: 'zzz'), isEmpty);
    });
  });

  group('cache-first loading', () {
    test('a successful refresh stores the snapshot for later offline reads', () async {
      final repo = EvacuationCenterRepository(
        cache: freshCache(),
        fetcher: okCenters,
      );

      final refreshed = await repo.refresh(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
      );
      expect(refreshed.offline, isFalse);
      expect(refreshed.hasCache, isTrue);
      expect(refreshed.centers.single['center_name'], 'Aklan State University');
      expect(refreshed.lastUpdated, isNotNull);

      final cached = await repo.getCached(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
      );
      expect(cached.hasCache, isTrue);
      expect(cached.centers, hasLength(1));
      expect(cached.centers.single['capacity'], 100);
      expect(cached.lastUpdated, isNotNull);
    });

    test('a failed refresh preserves the previously cached snapshot', () async {
      final db = freshCache();
      final good = EvacuationCenterRepository(cache: db, fetcher: okCenters);
      await good.refresh(userId: 1, role: 'barangay', barangayId: 5);

      final bad = EvacuationCenterRepository(cache: db, fetcher: failingCenters);
      final failed = await bad.refresh(userId: 1, role: 'barangay', barangayId: 5);
      expect(failed.offline, isTrue);

      final cached = await bad.getCached(userId: 1, role: 'barangay', barangayId: 5);
      expect(cached.hasCache, isTrue);
      expect(cached.centers.single['center_name'], 'Aklan State University');
    });

    test('repeated successful refreshes never duplicate rows', () async {
      final repo = EvacuationCenterRepository(
        cache: freshCache(),
        fetcher: okCenters,
      );
      await repo.refresh(userId: 1, role: 'barangay', barangayId: 5);
      await repo.refresh(userId: 1, role: 'barangay', barangayId: 5);

      final cached = await repo.getCached(userId: 1, role: 'barangay', barangayId: 5);
      expect(cached.centers, hasLength(1));
    });

    test('one municipality scope never sees another scope cache', () async {
      final repo = EvacuationCenterRepository(
        cache: freshCache(),
        fetcher: okCenters,
      );
      await repo.refresh(userId: 1, role: 'pho', municipality: 'Kalibo');

      final other = await repo.getCached(userId: 1, role: 'pho', municipality: 'Ibajay');
      expect(other.hasCache, isFalse);
      expect(other.centers, isEmpty);
    });
  });
}
