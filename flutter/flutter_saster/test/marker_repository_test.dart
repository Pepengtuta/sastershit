import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/services/marker_repository.dart';

Future<Map<String, dynamic>> okMapData({
  required String role,
  int? barangayId,
  int? userId,
  String? municipality,
}) async {
  return {
    'success': true,
    'data': {
      'barangay_halls': [
        {'id': 1, 'name': 'Andagaw Hall', 'latitude': 11.71, 'longitude': 122.37},
      ],
      'evacuation_centers': [
        {'id': 5, 'center_name': 'ASU Gym', 'barangay': 'Bakhawan', 'latitude': 11.70, 'longitude': 122.36},
      ],
      'pcf_facilities': [
        {'id': 9, 'name': 'Kalibo PCF', 'municipality': 'Kalibo', 'latitude': 11.70, 'longitude': 122.36},
      ],
      'incidents': [
        {'id': 42, 'barangay_name': 'Andagaw', 'status': 'Verified', 'created_at': '2026-09-21'},
      ],
    },
  };
}

Future<Map<String, dynamic>> failingMapData({
  required String role,
  int? barangayId,
  int? userId,
  String? municipality,
}) async {
  return {'success': false, 'message': 'No network'};
}

Future<Map<String, dynamic>> incompleteMapData({
  required String role,
  int? barangayId,
  int? userId,
  String? municipality,
}) async {
  return {
    'success': true,
    'data': {
      'barangay_halls': <Object>[],
      'evacuation_centers': <Object>[],
      'pcf_facilities': <Object>[],
      // 'incidents' omitted on purpose.
    },
  };
}

void main() {
  const dbName = 'saster_marker_cache.db';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDownAll(() async {
    await databaseFactory.deleteDatabase(dbName);
  });

  group('MarkerRepository.buildCacheKey', () {
    test('isolates users, roles, barangays, and municipalities', () {
      final a = MarkerRepository.buildCacheKey(
        userId: 1,
        role: 'barangay',
        barangayId: 3,
        municipality: 'Kalibo',
      );
      final b = MarkerRepository.buildCacheKey(
        userId: 1,
        role: 'barangay',
        barangayId: 3,
        municipality: 'Ibajay',
      );
      final c = MarkerRepository.buildCacheKey(
        userId: 2,
        role: 'barangay',
        barangayId: 3,
        municipality: 'Kalibo',
      );
      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(c)));
    });

    test('normalizes role and municipality case', () {
      final a = MarkerRepository.buildCacheKey(
        userId: 5,
        role: 'PCF',
        municipality: ' KALIBO ',
      );
      final b = MarkerRepository.buildCacheKey(
        userId: 5,
        role: 'pcf',
        municipality: 'kalibo',
      );
      expect(a, equals(b));
    });
  });

  test('refresh saves a complete snapshot and getCached restores it', () async {
    final repo = MarkerRepository(fetcher: okMapData);
    final refreshed = await repo.refresh(
      userId: 1,
      role: 'pho',
      municipality: 'Kalibo',
      requestUserId: 1,
      requestMunicipality: 'Kalibo',
    );

    expect(refreshed.offline, isFalse);
    expect(refreshed.hasCache, isTrue);
    expect(refreshed.lastUpdated, isNotNull);
    expect(refreshed.data['incidents'], hasLength(1));

    final cached = await repo.getCached(
      userId: 1,
      role: 'pho',
      municipality: 'Kalibo',
    );
    expect(cached.hasCache, isTrue);
    expect(cached.data['barangay_halls']!.first['name'], 'Andagaw Hall');
    expect(cached.data['incidents']!.first['id'], 42);
  });

  test('a failed refresh is offline and keeps the previous cache', () async {
    final seed = MarkerRepository(fetcher: okMapData);
    await seed.refresh(
      userId: 1,
      role: 'pho',
      municipality: 'Kalibo',
      requestMunicipality: 'Kalibo',
    );

    final repo = MarkerRepository(fetcher: failingMapData);
    final failed = await repo.refresh(
      userId: 1,
      role: 'pho',
      municipality: 'Kalibo',
      requestMunicipality: 'Kalibo',
    );

    expect(failed.offline, isTrue);

    final cached = await repo.getCached(
      userId: 1,
      role: 'pho',
      municipality: 'Kalibo',
    );
    expect(cached.hasCache, isTrue);
    expect(cached.data['incidents'], hasLength(1));
  });

  test('an incomplete payload is treated as offline and not stored', () async {
    final repo = MarkerRepository(fetcher: incompleteMapData);
    final result = await repo.refresh(
      userId: 1,
      role: 'barangay',
      barangayId: 3,
      municipality: 'Kalibo',
    );

    expect(result.offline, isTrue);

    final cached = await repo.getCached(
      userId: 1,
      role: 'barangay',
      barangayId: 3,
      municipality: 'Kalibo',
    );
    expect(cached.hasCache, isFalse);
  });
}