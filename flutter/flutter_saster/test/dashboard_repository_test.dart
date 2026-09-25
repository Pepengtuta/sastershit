import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/services/dashboard_cache_database.dart';
import 'package:flutter_saster/services/dashboard_repository.dart';

void main() {
  const dbName = 'test_dashboard_repo.db';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDownAll(() async {
    await databaseFactory.deleteDatabase(dbName);
  });

  DashboardCacheDatabase freshCache() => DashboardCacheDatabase(dbName: dbName);

  Future<Map<String, dynamic>> okSummary({
    required String role,
    int? barangayId,
    required int month,
    required int year,
    String subRole = '',
    int? userId,
    String? municipality,
  }) async {
    return {
      'success': true,
      'data': {
        'scope_label': role,
        'total_reports': 42,
        'pending': 3,
        'daily_trend': [
          {'label': 'Mon', 'count': 2},
        ],
      },
    };
  }

  Future<Map<String, dynamic>> failingSummary({
    required String role,
    int? barangayId,
    required int month,
    required int year,
    String subRole = '',
    int? userId,
    String? municipality,
  }) async {
    return {'success': false, 'message': 'No network'};
  }

  group('cache keys', () {
    test('keys isolate per user, scope, and month/year', () {
      final a = DashboardRepository.buildCacheKey(
        userId: 1,
        role: 'pho',
        month: 9,
        year: 2026,
      );
      final b = DashboardRepository.buildCacheKey(
        userId: 1,
        role: 'pho',
        month: 10,
        year: 2026,
      );
      final c = DashboardRepository.buildCacheKey(
        userId: 1,
        role: 'pho',
        month: 9,
        year: 2025,
      );
      final d = DashboardRepository.buildCacheKey(
        userId: 2,
        role: 'pho',
        month: 9,
        year: 2026,
      );
      final e = DashboardRepository.buildCacheKey(
        userId: 1,
        role: 'barangay',
        month: 9,
        year: 2026,
        barangayId: 5,
      );
      expect(a, isNot(b));
      expect(a, isNot(c));
      expect(a, isNot(d));
      expect(a, isNot(e));
    });

    test('sub-role and municipality are part of the key', () {
      final secretary = DashboardRepository.buildCacheKey(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
        subRole: 'secretary',
        month: 9,
        year: 2026,
      );
      final tanod = DashboardRepository.buildCacheKey(
        userId: 1,
        role: 'barangay',
        barangayId: 5,
        subRole: 'tanod',
        month: 9,
        year: 2026,
      );
      final withMuni = DashboardRepository.buildCacheKey(
        userId: 1,
        role: 'pcf',
        municipality: 'Kalibo',
        month: 9,
        year: 2026,
      );
      final withoutMuni = DashboardRepository.buildCacheKey(
        userId: 1,
        role: 'pcf',
        month: 9,
        year: 2026,
      );
      expect(secretary, isNot(tanod));
      expect(withMuni, isNot(withoutMuni));
    });
  });

  group('dashboard summary', () {
    test('refresh success stores the document for offline reads', () async {
      final repo = DashboardRepository(
        cache: freshCache(),
        fetcher: okSummary,
      );

      final refreshed = await repo.refresh(
        userId: 1,
        role: 'pho',
        month: 9,
        year: 2026,
      );
      expect(refreshed.offline, isFalse);
      expect(refreshed.hasCache, isTrue);
      expect(refreshed.data?['total_reports'], 42);
      expect(refreshed.lastUpdated, isNotNull);

      final cached = await repo.getCached(
        userId: 1,
        role: 'pho',
        month: 9,
        year: 2026,
      );
      expect(cached.hasCache, isTrue);
      expect(cached.data?['scope_label'], 'pho');
    });

    test('a failed refresh preserves the previous summary document', () async {
      final db = freshCache();
      final good = DashboardRepository(cache: db, fetcher: okSummary);
      await good.refresh(userId: 1, role: 'pho', month: 9, year: 2026);

      final bad = DashboardRepository(cache: db, fetcher: failingSummary);
      final failed = await bad.refresh(userId: 1, role: 'pho', month: 9, year: 2026);
      expect(failed.offline, isTrue);

      final cached = await bad.getCached(
        userId: 1,
        role: 'pho',
        month: 9,
        year: 2026,
      );
      expect(cached.hasCache, isTrue);
      expect(cached.data?['total_reports'], 42);
    });

    test('first open while offline has no cache until a successful fetch', () async {
      final repo = DashboardRepository(
        cache: freshCache(),
        fetcher: failingSummary,
      );

      final first = await repo.refresh(userId: 2, role: 'pho', month: 9, year: 2026);
      expect(first.offline, isTrue);
      expect(first.hasCache, isFalse);
      expect(first.data, isNull);

      final cached = await repo.getCached(
        userId: 2,
        role: 'pho',
        month: 9,
        year: 2026,
      );
      expect(cached.hasCache, isFalse);
    });

    test('one month scope never sees another month cache', () async {
      final repo = DashboardRepository(cache: freshCache(), fetcher: okSummary);
      await repo.refresh(userId: 1, role: 'pho', month: 9, year: 2026);

      final oct = await repo.getCached(
        userId: 1,
        role: 'pho',
        month: 10,
        year: 2026,
      );
      expect(oct.hasCache, isFalse);
    });

    test('a successful refresh replaces the stale cached summary', () async {
      final db = freshCache();
      final good = DashboardRepository(cache: db, fetcher: okSummary);
      await good.refresh(userId: 1, role: 'pho', month: 9, year: 2026);

      Future<Map<String, dynamic>> biggerSummary({
        required String role,
        int? barangayId,
        required int month,
        required int year,
        String subRole = '',
        int? userId,
        String? municipality,
      }) async {
        return {
          'success': true,
          'data': {
            'scope_label': role,
            'total_reports': 99,
          },
        };
      }

      final next = DashboardRepository(cache: db, fetcher: biggerSummary);
      final refreshed = await next.refresh(userId: 1, role: 'pho', month: 9, year: 2026);
      expect(refreshed.data?['total_reports'], 99);

      final cached = await next.getCached(
        userId: 1,
        role: 'pho',
        month: 9,
        year: 2026,
      );
      expect(cached.data?['total_reports'], 99);
    });
  });
}