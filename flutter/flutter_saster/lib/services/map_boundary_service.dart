import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A named administrative boundary loaded from the bundled GeoJSON files.
class MapBoundary {
  const MapBoundary({
    required this.name,
    required this.municipality,
    required this.level,
    required this.rings,
  });

  final String name;
  final String municipality;
  final String level;

  /// One or more closed rings (Polygon/MultiPolygon).
  final List<List<LatLng>> rings;

  bool get isMunicipality => level == 'municipality';
}

/// Where the camera should start, derived exclusively from bundled boundaries
/// plus the signed-in session — never from the network.
class MapCameraPlan {
  const MapCameraPlan({
    required this.center,
    required this.zoom,
    required this.source,
    this.fitBounds,
  });

  final LatLng center;
  final double zoom;
  final LatLngBounds? fitBounds;

  /// 'barangay' | 'municipality' | 'province' | 'fallback'.
  final String source;
}

class MapBoundaryService {
  MapBoundaryService._();

  static const String kaliboAsset = 'assets/data/kalibo_barangays.geojson';
  static const String ibajayAsset = 'assets/data/ibajay_puroks.geojson';

  static const LatLng aklanFallbackCenter = LatLng(11.7069, 122.2800);

  static Future<List<MapBoundary>> loadKalibo() => _load(
    kaliboAsset,
    defaultMunicipality: 'Kalibo',
    includeMunicipalityLevel: false,
  );

  static Future<List<MapBoundary>> loadIbajay() => _load(
    ibajayAsset,
    defaultMunicipality: 'Ibajay',
    includeMunicipalityLevel: true,
  );

  static Future<List<MapBoundary>> loadAll() async => [
    ...await loadKalibo(),
    ...await loadIbajay(),
  ];

  /// Parses a bundled GeoJSON file of boundaries into [MapBoundary] rows.
  ///
  /// Kalibo exports name the barangay as `adm4_en` (never `name`), so every
  /// plausible key is tried. Ibajay marks its single municipality-level shape
  /// as `level == 'municipality'`, which is kept so the camera can land on the
  /// whole municipality.
  static Future<List<MapBoundary>> _load(
    String asset, {
    required String defaultMunicipality,
    required bool includeMunicipalityLevel,
  }) async {
    String raw;
    try {
      raw = await rootBundle.loadString(asset);
    } catch (_) {
      return const [];
    }

    final geojson = jsonDecode(raw) as Map<String, dynamic>;
    final features = (geojson['features'] as List?) ?? const [];
    final boundaries = <MapBoundary>[];

    for (final feature in features) {
      final f = Map<String, dynamic>.from(feature as Map);
      final geometry = Map<String, dynamic>.from((f['geometry'] ?? {}) as Map);
      final properties = Map<String, dynamic>.from(
        (f['properties'] ?? {}) as Map,
      );

      final level = properties['level']?.toString() ?? 'barangay';
      if (level == 'municipality' && !includeMunicipalityLevel) continue;

      final name =
          properties['name']?.toString() ??
          properties['NAME_3']?.toString() ??
          properties['adm4_en']?.toString() ??
          '';
      final municipality =
          properties['municipality']?.toString() ??
          defaultMunicipality;

      final type = geometry['type']?.toString();
      final coordinates = geometry['coordinates'];
      final rings = <List<LatLng>>[];

      void addRing(List<LatLng> points) {
        if (points.length >= 3) rings.add(points);
      }

      if (type == 'Polygon' && coordinates is List) {
        addRing(_pointsFromRing(coordinates.first as List));
      }

      if (type == 'MultiPolygon' && coordinates is List) {
        for (final polygon in coordinates) {
          if (polygon is List && polygon.isNotEmpty) {
            addRing(_pointsFromRing(polygon.first as List));
          }
        }
      }

      if (rings.isNotEmpty && name.trim().isNotEmpty) {
        boundaries.add(
          MapBoundary(
            name: name,
            municipality: municipality,
            level: level,
            rings: rings,
          ),
        );
      }
    }

    return boundaries;
  }

  /// Chooses the camera from bundled boundaries using the saved session:
  ///
  /// 1. the user's barangay boundary (matched inside their municipality when
  ///    known, so an Ibajay user never lands on a same-named Kalibo area);
  /// 2. the user's municipality boundary (explicit shape or the union of its
  ///    barangays);
  /// 3. the province-wide union of every bundled boundary.
  static MapCameraPlan resolveCameraPlan({
    required List<MapBoundary> boundaries,
    String? barangayName,
    String? municipality,
  }) {
    final barangays = boundaries.where((b) => !b.isMunicipality).toList();
    final municipalityShapes = boundaries
        .where((b) => b.isMunicipality)
        .toList();

    final muniKey = _norm(municipality);
    final brgyKey = _norm(barangayName);

    // 1. Barangay boundary.
    if (brgyKey.isNotEmpty) {
      final allMatches = barangays
          .where((b) => _norm(b.name) == brgyKey)
          .toList();
      final scoped = muniKey.isEmpty
          ? allMatches
          : allMatches
                .where((b) => _norm(b.municipality) == muniKey)
                .toList();
      final pool = scoped.isNotEmpty ? scoped : allMatches;
      final match = _firstWithGeometry(pool);
      if (match != null) {
        return _plan(_boundsForBoundary(match), 'barangay');
      }
    }

    // 2. Municipality boundary.
    if (muniKey.isNotEmpty) {
      final explicit = municipalityShapes
          .where(
            (b) =>
                _norm(b.name) == muniKey || _norm(b.municipality) == muniKey,
          )
          .toList();
      final chosen = _firstWithGeometry(explicit);
      if (chosen != null) {
        return _plan(_boundsForBoundary(chosen), 'municipality');
      }

      final union = _union(
        barangays.where((b) => _norm(b.municipality) == muniKey),
      );
      if (union != null) {
        return _plan(union, 'municipality');
      }
    }

    // 3. Province-wide union of every bundled boundary.
    final province = _union(boundaries);
    if (province != null) {
      return _plan(province, 'province');
    }

    return MapCameraPlan(
      center: aklanFallbackCenter,
      zoom: 11.2,
      source: 'fallback',
    );
  }

  static MapCameraPlan _plan(LatLngBounds? bounds, String source) {
    if (bounds == null) {
      return MapCameraPlan(
        center: aklanFallbackCenter,
        zoom: 11.2,
        source: 'fallback',
      );
    }
    return MapCameraPlan(
      center: bounds.center,
      zoom: zoomForBounds(bounds),
      fitBounds: bounds,
      source: source,
    );
  }

  static MapBoundary? _firstWithGeometry(List<MapBoundary> pool) {
    for (final boundary in pool) {
      if (boundary.rings.any((ring) => ring.length >= 3)) return boundary;
    }
    return null;
  }

  /// Bounding box spanning every ring of a MultiPolygon boundary.
  static LatLngBounds? _boundsForBoundary(MapBoundary boundary) {
    LatLngBounds? bounds;
    for (final ring in boundary.rings) {
      for (final point in ring) {
        bounds = expandBounds(bounds, point);
      }
    }
    return bounds;
  }

  static LatLngBounds? _union(Iterable<MapBoundary> boundaries) {
    LatLngBounds? bounds;
    for (final boundary in boundaries) {
      for (final ring in boundary.rings) {
        for (final point in ring) {
          bounds = expandBounds(bounds, point);
        }
      }
    }
    return bounds;
  }

  /// Expands [bounds] to include [point]; seeds a new bounds when null.
  static LatLngBounds expandBounds(LatLngBounds? bounds, LatLng point) {
    if (bounds == null) return LatLngBounds(point, point);
    final swLat = math.min(bounds.south, point.latitude);
    final swLng = math.min(bounds.west, point.longitude);
    final neLat = math.max(bounds.north, point.latitude);
    final neLng = math.max(bounds.east, point.longitude);
    return LatLngBounds(LatLng(swLat, swLng), LatLng(neLat, neLng));
  }

  static double zoomForBounds(LatLngBounds bounds) {
    final dLat = (bounds.north - bounds.south).abs();
    final midLat = (bounds.north + bounds.south) / 2 * math.pi / 180;
    final dLng =
        (bounds.east - bounds.west).abs() *
        math.max(math.cos(midLat).abs(), 0.01);
    final span = math.max(dLat, dLng);
    if (span <= 0.0002) return 16;
    final zoom = math.log(360 / span) / math.ln2;
    return zoom.clamp(12.0, 16.0);
  }

  static List<LatLng> _pointsFromRing(List ring) {
    final points = <LatLng>[];
    for (final pair in ring) {
      if (pair is List && pair.length >= 2) {
        final lng = _toDouble(pair[0]);
        final lat = _toDouble(pair[1]);
        if (lat != null && lng != null) points.add(LatLng(lat, lng));
      }
    }
    return points;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _norm(String? value) => (value ?? '').trim().toLowerCase();
}