import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_saster/services/map_boundary_service.dart';

MapBoundary _brgy(String name, String muni, double lat, double lng) {
  return MapBoundary(
    name: name,
    municipality: muni,
    level: 'barangay',
    rings: [
      [
        LatLng(lat - 0.01, lng - 0.01),
        LatLng(lat - 0.01, lng + 0.01),
        LatLng(lat + 0.01, lng + 0.01),
        LatLng(lat + 0.01, lng - 0.01),
      ],
    ],
  );
}

MapBoundary _muni(String name, double lat, double lng) {
  return MapBoundary(
    name: name,
    municipality: name,
    level: 'municipality',
    rings: [
      [
        LatLng(lat - 0.1, lng - 0.1),
        LatLng(lat - 0.1, lng + 0.1),
        LatLng(lat + 0.1, lng + 0.1),
        LatLng(lat + 0.1, lng - 0.1),
      ],
    ],
  );
}

void main() {
  group('MapBoundaryService.resolveCameraPlan', () {
    test('prefers the signed-in barangay over the municipality', () {
      final boundaries = [
        _muni('Kalibo', 11.7069, 122.3644),
        _brgy('Andagaw', 'Kalibo', 11.71, 122.37),
      ];
      final plan = MapBoundaryService.resolveCameraPlan(
        boundaries: boundaries,
        barangayName: 'andagaw',
        municipality: '',
      );
      expect(plan.source, 'barangay');
      expect(plan.fitBounds, isNotNull);
      expect(plan.center.latitude, closeTo(11.71, 0.001));
    });

    test('an Ibajay user never lands on a same-named Kalibo barangay', () {
      // Kalibo and Ibajay both have a "Poblacion".
      final kaliboPoblacion = _brgy('Poblacion', 'Kalibo', 11.71, 122.37);
      final ibajayPoblacion = _brgy('Poblacion', 'Ibajay', 11.79, 122.16);
      final plan = MapBoundaryService.resolveCameraPlan(
        boundaries: [kaliboPoblacion, ibajayPoblacion],
        barangayName: 'Poblacion',
        municipality: 'Ibajay',
      );
      expect(plan.source, 'barangay');
      // The camera must sit over Ibajay (west), not Kalibo.
      expect(plan.center.longitude, lessThan(122.30));
      final containsIbajay =
          plan.fitBounds!.contains(ibajayPoblacion.rings.first.first);
      final containsKalibo = plan.fitBounds!.contains(
        kaliboPoblacion.rings.first.first,
      );
      expect(containsIbajay, isTrue);
      expect(containsKalibo, isFalse);
    });

    test('falls back to the municipality boundary for admin roles', () {
      final plan = MapBoundaryService.resolveCameraPlan(
        boundaries: [
          _brgy('Andagaw', 'Kalibo', 11.71, 122.37),
          _muni('Kalibo', 11.7069, 122.3644),
        ],
        barangayName: null,
        municipality: 'Kalibo',
      );
      expect(plan.source, 'municipality');
    });

    test('builds a municipality boundary from the union of its barangays', () {
      final plan = MapBoundaryService.resolveCameraPlan(
        boundaries: [
          _brgy('Andagaw', 'Kalibo', 11.71, 122.35),
          _brgy('Poblacion', 'Kalibo', 11.70, 122.38),
          _brgy('Poblacion', 'Ibajay', 11.79, 122.16),
        ],
        barangayName: 'Does Not Exist',
        municipality: 'Kalibo',
      );
      expect(plan.source, 'municipality');
      // Only Kalibo barangays are included, so Ibajay is outside the fit.
      final containsIbajay = plan.fitBounds!.contains(
        LatLng(11.79, 122.16),
      );
      expect(containsIbajay, isFalse);
    });

    test('falls back to the province-wide union', () {
      final plan = MapBoundaryService.resolveCameraPlan(
        boundaries: [
          _brgy('Andagaw', 'Kalibo', 11.71, 122.37),
          _brgy('Poblacion', 'Ibajay', 11.79, 122.16),
        ],
        barangayName: null,
        municipality: null,
      );
      expect(plan.source, 'province');
      expect(plan.fitBounds, isNotNull);
      expect(plan.fitBounds!.contains(LatLng(11.71, 122.37)), isTrue);
      expect(plan.fitBounds!.contains(LatLng(11.79, 122.16)), isTrue);
    });

    test('uses a fixed fallback when no boundaries exist', () {
      final plan = MapBoundaryService.resolveCameraPlan(
        boundaries: const [],
        barangayName: 'Anything',
        municipality: null,
      );
      expect(plan.source, 'fallback');
      expect(plan.fitBounds, isNull);
    });
  });

  group('MapBoundaryService bundled asset loading', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('parses both bundled GeoJSON files with names and municipalities', () async {
      final all = await MapBoundaryService.loadAll();
      expect(all, isNotEmpty);
      expect(all.every((b) => b.name.trim().isNotEmpty), isTrue);
      // Kalibo exports use adm4_en (e.g. "Andagaw"), which must be read.
      expect(all.any((b) => b.name.toLowerCase() == 'andagaw'), isTrue);
      expect(all.any((b) => b.municipality == 'Kalibo'), isTrue);
      expect(all.any((b) => b.municipality == 'Ibajay'), isTrue);
    });

    test('keeps the Ibajay municipality-level shape for camera fitting', () async {
      final ibajay = await MapBoundaryService.loadIbajay();
      expect(ibajay.any((b) => b.isMunicipality), isTrue);
    });
  });
}