import 'package:flutter_test/flutter_test.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/services/create_incident_cache_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CreateIncidentCacheDatabase', () {
    test('round-trips disaster types and tracks last updated', () async {
      final cache = CreateIncidentCacheDatabase.instance;
      final now = DateTime.now();

      await cache.replaceDisasterTypes(
        rows: [
          {'id': 1, 'name': 'Typhoon', 'is_natural': 1},
          {'id': 9, 'name': 'Accident / Mass Casualty Incident', 'is_natural': 0},
        ],
        updatedAt: now,
      );

      final rows = await cache.getDisasterTypes();
      expect(rows, hasLength(2));
      expect(rows.first['name'], 'Typhoon');
      expect(rows.first['is_natural'], 1);
      expect(rows.last['name'], 'Accident / Mass Casualty Incident');
      expect(rows.last['is_natural'], 0);
      expect(await cache.getDisasterTypesLastUpdated(), isNotNull);
    });

    test('replacing disaster types drops removed rows', () async {
      final cache = CreateIncidentCacheDatabase.instance;

      await cache.replaceDisasterTypes(
        rows: [{'id': 1, 'name': 'Typhoon', 'is_natural': 1}],
        updatedAt: DateTime.now(),
      );

      expect(await cache.getDisasterTypes(), hasLength(1));
    });

    test('evacuation centers are isolated per barangay scope', () async {
      final cache = CreateIncidentCacheDatabase.instance;

      await cache.replaceEvacuationCenters(
        barangayId: 1,
        barangayName: 'Andagaw',
        rows: [
          {'id': 7, 'center_name': 'Aklan State University', 'status': 'Available'},
        ],
        updatedAt: DateTime.now(),
      );
      await cache.replaceEvacuationCenters(
        barangayId: 2,
        barangayName: 'Bachaw Norte',
        rows: [
          {'id': 55, 'center_name': 'Bachaw Barangay Hall'},
        ],
        updatedAt: DateTime.now(),
      );

      final andagaw = await cache.getEvacuationCenters(
        barangayId: 1,
        barangayName: 'Andagaw',
      );
      final bachaw = await cache.getEvacuationCenters(
        barangayId: 2,
        barangayName: 'Bachaw Norte',
      );

      expect(andagaw, hasLength(1));
      expect(andagaw.single['center_name'], 'Aklan State University');
      expect(andagaw.single['status'], 'Available');
      expect(bachaw.single['center_name'], 'Bachaw Barangay Hall');

      expect(await cache.getEvacuationCenters(barangayId: 1, barangayName: 'Bachaw Norte'), isEmpty);
      expect(await cache.getEvacuationCentersLastUpdated(barangayId: 2, barangayName: 'Bachaw Norte'), isNotNull);
    });
  });
}