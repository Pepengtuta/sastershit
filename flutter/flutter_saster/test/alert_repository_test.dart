import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/services/alert_cache_database.dart';
import 'package:flutter_saster/services/alert_repository.dart';

void main() {
  const dbName = 'test_alert_repo.db';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDownAll(() async {
    await databaseFactory.deleteDatabase(dbName);
  });

  AlertCacheDatabase freshCache() => AlertCacheDatabase(dbName: dbName);

  Future<Map<String, dynamic>> okAlerts({
    required String role,
    int? barangayId,
    int? userId,
    String search = '',
  }) async {
    return {
      'success': true,
      'data': [
        {
          'id': 1,
          'title': 'Typhoon Signal No. 3',
          'message': 'Heavy rainfall expected',
          'alert_type': 'weather',
          'instructions': 'Evacuate low areas',
          'severity': 'High',
          'validity_status': 'Active',
          'start_datetime': '2026-09-20 08:00:00',
          'end_datetime': '2026-09-22 08:00:00',
          'created_by_name': 'Alice',
          'created_by_role': 'pcf',
          'target_type': 'all',
          'target_label': 'All Barangays',
          'is_read': 0,
        },
        {
          'id': 2,
          'title': 'Meeting Rescheduled',
          'message': 'Joint meeting moved',
          'alert_type': 'advisory',
          'instructions': 'Kindly confirm',
          'severity': 'Moderate',
          'validity_status': 'Active',
          'start_datetime': '2026-09-21 09:00:00',
          'end_datetime': '2026-09-21 11:00:00',
          'created_by_name': 'Bong',
          'created_by_role': 'barangay',
          'target_type': 'selected',
          'target_label': 'Barangay Poblacion',
          'is_read': 0,
        },
      ],
    };
  }

  Future<Map<String, dynamic>> failingAlerts({
    required String role,
    int? barangayId,
    int? userId,
    String search = '',
  }) async {
    return {'success': false, 'message': 'No network'};
  }

  group('cache keys', () {
    test('keys isolate per user and per barangay scope', () {
      final a = AlertRepository.buildCacheKey(userId: 1, role: 'barangay', barangayId: 5);
      final b = AlertRepository.buildCacheKey(userId: 1, role: 'barangay', barangayId: 6);
      final c = AlertRepository.buildCacheKey(userId: 2, role: 'barangay', barangayId: 5);
      final d = AlertRepository.buildCacheKey(userId: 1, role: 'pcf');
      expect(a, isNot(b));
      expect(a, isNot(c));
      expect(a, isNot(d));
    });
  });

  group('alert list', () {
    test('refresh success stores the full list for offline reads', () async {
      final repo = AlertRepository(cache: freshCache(), fetcher: okAlerts);

      final refreshed = await repo.refresh(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
      );
      expect(refreshed.offline, isFalse);
      expect(refreshed.hasCache, isTrue);
      expect(refreshed.alerts, hasLength(2));
      expect(refreshed.lastUpdated, isNotNull);

      final cached = await repo.getCached(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
      );
      expect(cached.hasCache, isTrue);
      expect(cached.alerts, hasLength(2));
      expect(cached.alerts.first['title'], 'Typhoon Signal No. 3');
    });

    test('search is applied locally to the cached snapshot', () async {
      final good = AlertRepository(cache: freshCache(), fetcher: okAlerts);
      await good.refresh(userId: 1, role: 'barangay', barangayId: 5);

      final repo = good;
      final byTitle = await repo.getCached(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
        search: 'typhoon',
      );
      expect(byTitle.alerts, hasLength(1));
      expect(byTitle.alerts.single['id'], 1);

      final byMessage = await repo.getCached(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
        search: 'rainfall',
      );
      expect(byMessage.alerts, hasLength(1));

      final byInstructions = await repo.getCached(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
        search: 'evacuate',
      );
      expect(byInstructions.alerts, hasLength(1));

      final byType = await repo.getCached(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
        search: 'advisory',
      );
      expect(byType.alerts, hasLength(1));

      final noMatch = await repo.getCached(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
        search: 'zzz',
      );
      expect(noMatch.alerts, isEmpty);
      expect(noMatch.hasCache, isTrue);
    });

    test('a failed refresh preserves the previous alert list', () async {
      final db = freshCache();
      final good = AlertRepository(cache: db, fetcher: okAlerts);
      await good.refresh(userId: 1, role: 'barangay', barangayId: 5);

      final bad = AlertRepository(cache: db, fetcher: failingAlerts);
      final failed = await bad.refresh(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
        search: 'typhoon',
      );
      expect(failed.offline, isTrue);

      final cached = await bad.getCached(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
      );
      expect(cached.hasCache, isTrue);
      expect(cached.alerts, hasLength(2));
    });

    test('first open while offline has no cache until a successful fetch', () async {
      final repo = AlertRepository(cache: freshCache(), fetcher: failingAlerts);

      final first = await repo.refresh(userId: 2, role: 'barangay', barangayId: 5);
      expect(first.offline, isTrue);
      expect(first.hasCache, isFalse);
      expect(first.alerts, isEmpty);

      final cached = await repo.getCached(
        userId: 2,
        role: 'barangay',
        barangayId: 5,
      );
      expect(cached.hasCache, isFalse);
      expect(cached.alerts, isEmpty);
    });

    test('one user scope never sees another user scope cache', () async {
      final repo = AlertRepository(cache: freshCache(), fetcher: okAlerts);
      await repo.refresh(userId: 1, role: 'barangay', barangayId: 5);

      final other = await repo.getCached(
        userId: 9,
        role: 'barangay',
        barangayId: 5,
      );
      expect(other.hasCache, isFalse);

      final otherBarangay = await repo.getCached(
        userId: 1,
        role: 'barangay',
        barangayId: 6,
      );
      expect(otherBarangay.hasCache, isFalse);
    });
  });
}