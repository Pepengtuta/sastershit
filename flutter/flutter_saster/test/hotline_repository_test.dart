import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_saster/services/hotline_repository.dart';

void main() {
  group('HotlineRepository.buildCacheKey', () {
    test('differs between users with the same scope', () {
      final userA = HotlineRepository.buildCacheKey(
        userId: 21,
        role: 'barangay',
        barangayId: 5,
        municipality: 'Kalibo',
      );
      final userB = HotlineRepository.buildCacheKey(
        userId: 22,
        role: 'barangay',
        barangayId: 5,
        municipality: 'Kalibo',
      );
      expect(userA, isNot(equals(userB)));
    });

    test('differs between access scopes of the same user', () {
      final user = HotlineRepository.buildCacheKey(
        userId: 7,
        role: 'pcf',
        municipality: 'Kalibo',
      );
      final otherMuni = HotlineRepository.buildCacheKey(
        userId: 7,
        role: 'pcf',
        municipality: 'Ibajay',
      );
      final otherRole = HotlineRepository.buildCacheKey(userId: 7, role: 'pho');
      expect(user, isNot(equals(otherMuni)));
      expect(user, isNot(equals(otherRole)));
    });

    test('is stable for identical inputs and normalizes municipality case', () {
      final a = HotlineRepository.buildCacheKey(
        userId: 3,
        role: 'PCF',
        barangayId: null,
        municipality: 'KALIBO',
      );
      final b = HotlineRepository.buildCacheKey(
        userId: 3,
        role: 'pcf',
        municipality: 'kalibo',
      );
      expect(a, equals(b));
    });
  });

  group('HotlineRepository.filterLocally', () {
    final rows = <Map<String, dynamic>>[
      {
        'id': 1,
        'hotline_scope': 'Barangay',
        'office_name': 'Barangay Hall Andagao',
        'municipality': 'Kalibo',
        'category': 'Barangay',
        'telephone_numbers': null,
        'cellphone_numbers': '09171112222',
        'hotline_number': '2681234',
      },
      {
        'id': 2,
        'hotline_scope': 'Municipal',
        'office_name': 'Kalibo PNP',
        'municipality': 'Kalibo',
        'category': 'PNP',
        'telephone_numbers': '2684567',
        'cellphone_numbers': null,
        'hotline_number': null,
      },
      {
        'id': 3,
        'hotline_scope': 'Municipal',
        'office_name': 'Ibajay Fire Station',
        'municipality': 'Ibajay',
        'category': 'Fire',
        'telephone_numbers': null,
        'cellphone_numbers': '09283334444',
        'hotline_number': null,
      },
    ];

    test('returns everything for All / empty search', () {
      final result = HotlineRepository.filterLocally(
        rows,
        search: '',
        category: 'All',
      );
      expect(result.length, 3);
    });

    test('filters by Barangay scope chip', () {
      final result = HotlineRepository.filterLocally(
        rows,
        search: '',
        category: 'Barangay',
      );
      expect(result.length, 1);
      expect(result.single['id'], 1);
    });

    test('filters by Municipal scope chip', () {
      final result = HotlineRepository.filterLocally(
        rows,
        search: '',
        category: 'Municipal',
      );
      expect(result.length, 2);
    });

    test('filters by non-scope category chip (PNP, case-insensitive)', () {
      final result = HotlineRepository.filterLocally(
        rows,
        search: '',
        category: 'pnp',
      );
      expect(result.length, 1);
      expect(result.single['office_name'], 'Kalibo PNP');
    });

    test('search matches office name and phone fields', () {
      expect(
        HotlineRepository.filterLocally(
          rows,
          search: 'ibajay',
          category: 'All',
        ).length,
        1,
      );
      expect(
        HotlineRepository.filterLocally(
          rows,
          search: '0917111',
          category: 'All',
        ).length,
        1,
      );
      expect(
        HotlineRepository.filterLocally(
          rows,
          search: 'not-there',
          category: 'All',
        ),
        isEmpty,
      );
    });
  });
}
