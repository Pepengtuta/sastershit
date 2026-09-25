import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_saster/services/create_incident_repository.dart';

void main() {
  group('CreateIncidentRepository.evacuationCacheKey', () {
    test('differs between barangays', () {
      final kalibo = CreateIncidentRepository.evacuationCacheKey(
        barangayId: 1,
        barangayName: 'Andagaw',
      );
      final ibajay = CreateIncidentRepository.evacuationCacheKey(
        barangayId: 2,
        barangayName: 'Bachaw Norte',
      );
      expect(kalibo, isNot(equals(ibajay)));
    });

    test('is stable and normalizes barangay-name case', () {
      final a = CreateIncidentRepository.evacuationCacheKey(
        barangayId: 5,
        barangayName: 'POBLACION',
      );
      final b = CreateIncidentRepository.evacuationCacheKey(
        barangayId: 5,
        barangayName: 'poblacion',
      );
      expect(a, equals(b));
    });

    test('differs between barangay ids even with the same name', () {
      final a = CreateIncidentRepository.evacuationCacheKey(
        barangayId: 3,
        barangayName: 'Poblacion',
      );
      final b = CreateIncidentRepository.evacuationCacheKey(
        barangayId: 4,
        barangayName: 'Poblacion',
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('CreateIncidentRepository.naturalDisasterNames', () {
    final rows = <Map<String, dynamic>>[
      {'name': 'Typhoon', 'is_natural': 1},
      {'name': 'Flood', 'is_natural': 1},
      {'name': 'Accident / Mass Casualty Incident', 'is_natural': 0},
      {'name': 'Others', 'is_natural': 0},
    ];

    test('returns only names flagged natural', () {
      final naturals = CreateIncidentRepository.naturalDisasterNames(rows);
      expect(naturals, containsAll(['Typhoon', 'Flood']));
      expect(naturals, isNot(contains('Accident / Mass Casualty Incident')));
      expect(naturals, isNot(contains('Others')));
    });

    test('treats every type as natural when the server omits the flag', () {
      final legacy = rows
          .map((r) => Map<String, dynamic>.from(r)..remove('is_natural'))
          .toList();
      final naturals = CreateIncidentRepository.naturalDisasterNames(legacy);
      expect(naturals, containsAll([
        'Typhoon',
        'Flood',
        'Accident / Mass Casualty Incident',
        'Others',
      ]));
    });

    test('drops rows without a name', () {
      final naturals = CreateIncidentRepository.naturalDisasterNames([
        {'name': 'Flood', 'is_natural': 1},
        {'name': '', 'is_natural': 1},
        {'name': null, 'is_natural': 1},
      ]);
      expect(naturals, equals({'Flood'}));
    });
  });
}