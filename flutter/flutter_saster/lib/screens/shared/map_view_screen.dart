import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/app_colors.dart';
import '../../constants/status_labels.dart';
import '../../services/auth_service.dart';
import '../../services/map_boundary_service.dart';
import '../../services/marker_repository.dart';
import '../../widgets/hotline_reconnect_mixin.dart';
import '../../widgets/offline_map_layer.dart';

class MapViewScreen extends StatefulWidget {
  final String role;
  final int refreshToken;

  const MapViewScreen({super.key, required this.role, this.refreshToken = 0});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen>
    with HotlineReconnectMixin<MapViewScreen> {
  /// Marker/API state is kept separate from offline tile preparation
  /// (handled inside [OfflineMapLayer]) so a failed request never hides the
  /// offline base map.
  bool _markersLoading = true;
  bool _markersOffline = false;
  bool _markerSyncInProgress = false;

  /// True while the shown markers come from the last saved snapshot rather
  /// than a live response. Tags marker details with "Saved data".
  bool _markersFromCache = false;
  DateTime? _lastSyncedAt;

  final MarkerRepository _markerRepository = MarkerRepository.instance;

  /// The acting role for both the cache key and the API request.
  String get _effectiveRole => (AuthService.currentRole ?? widget.role).toLowerCase();

  /// Cache scope derived from everything the server uses to filter map data,
  /// so records can never leak between users or access scopes. The request
  /// verbatim municipality is only sent for admin roles.
  String? get _markerRequestMunicipality => _isSuperadmin && _selectedMunicipality.isNotEmpty
      ? _selectedMunicipality
      : null;

  List<MapBoundary> kaliboBoundaries = [];
  List<MapBoundary> ibajayBoundaries = [];
  String autoHighlightName = '';
  List<Map<String, dynamic>> barangayHalls = [];
  List<Map<String, dynamic>> evacuationCenters = [];
  List<Map<String, dynamic>> pcfFacilities = [];
  List<Map<String, dynamic>> incidents = [];

  bool showBarangayHalls = true;
  bool showEvacuationCenters = true;
  bool showPcfFacilities = true;
  bool showIncidents = true;

  /// Optional "Forwarded to MDR" layer (Governor/pho only): MDR-level incidents
  /// rendered orange. Off by default so the default map is unchanged.
  bool showMdrEscalations = false;

  static const Set<String> _mdrStatuses = {
    'Forwarded to PCF',
    'Under MDR Review',
    'Verified',
    'Responding',
  };

  bool get _isPhoRole {
    final r = (AuthService.currentRole ?? widget.role).toLowerCase();
    return r == 'pho';
  }

  final MapController mapController = MapController();

  /// Name of the tapped boundary; red-shades it like the web's selected style.
  String? selectedPolygonName;

  /// Camera view the screen loaded with; used by the "Reset Map" action.
  LatLngBounds? _defaultFitBounds;
  LatLng _defaultFallbackCenter = const LatLng(11.7069, 122.3644);
  double _defaultFallbackZoom = 12.4;

  double currentZoom = 12.4;
  double initialZoom = 12.4;
  final LatLng kaliboCenter = const LatLng(11.7069, 122.3644);
  final LatLng ibajayCenter = const LatLng(11.7331, 122.1590);
  LatLng mapCenter = const LatLng(11.7069, 122.3644);

  late String _selectedMunicipality;

  bool get _isSuperadmin {
    final r = (AuthService.currentRole ?? widget.role).toLowerCase();
    return r == 'superadmin' || r == 'pcf' || r == 'pho';
  }

  bool get _isMdrForced => AuthService.isMdrKalibo || AuthService.isMdrIbajay;

  String get _resolvedMunicipality =>
      AuthService.effectiveMunicipality ??
      AuthService.currentMunicipality ??
      '';

  bool get _municipalityScoped {
    final r = (AuthService.currentRole ?? widget.role).toLowerCase();
    return r == 'barangay' ||
        r == 'brgy' ||
        _isMdrForced ||
        AuthService.isMayor;
  }

  bool get isIbajayPrimary => _selectedMunicipality.toLowerCase() == 'ibajay';

  @override
  void initState() {
    super.initState();
    _selectedMunicipality = _resolvedMunicipality;
    loadMap();
  }

  @override
  void didUpdateWidget(covariant MapViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final globalMuni = _resolvedMunicipality;
    if (globalMuni != _selectedMunicipality) {
      _selectedMunicipality = globalMuni;
    }
    if (oldWidget.refreshToken != widget.refreshToken) {
      loadMap();
    }
  }

  Future<void> loadMap() async {
    // Cache-first: show the last saved snapshot immediately if one exists for
    // this scope, then refresh from the network in the background. The camera
    // is placed from bundled boundaries + the saved session (never from the
    // network), so it is correct on first open and while offline.
    final userId = AuthService.currentUserId ?? 0;
    final role = AuthService.currentRole ?? widget.role;

    final cached = await _markerRepository.getCached(
      userId: userId,
      role: role,
      barangayId: AuthService.currentBarangayId,
      municipality: _selectedMunicipality,
    );

    if (mounted) {
      setState(() {
        _lastSyncedAt = cached.lastUpdated;
        if (cached.hasCache) {
          _applyMarkerData(cached.data);
          _markersFromCache = true;
          _markersLoading = false;
          _markersOffline = false;
        } else {
          _markersLoading = true;
        }
      });
    }

    try {
      final isBarangay =
          _effectiveRole == 'barangay' || _effectiveRole == 'brgy';
      final highlightName = isBarangay
          ? (AuthService.currentBarangayName ?? '').trim()
          : '';
      selectedPolygonName = null;

      final allKalibo = await MapBoundaryService.loadKalibo();
      final allIbajay = await MapBoundaryService.loadIbajay();

      final renderKalibo = (_municipalityScoped && isIbajayPrimary)
          ? const <MapBoundary>[]
          : allKalibo;
      final renderIbajay = (_municipalityScoped && !isIbajayPrimary)
          ? const <MapBoundary>[]
          : allIbajay;

      // Camera priority: user barangay -> user municipality -> Aklan-wide.
      // Bundled boundaries never depend on connectivity or marker sync.
      var plan = MapBoundaryService.resolveCameraPlan(
        boundaries: [...allKalibo, ...allIbajay],
        barangayName: AuthService.currentBarangayName,
        municipality: _selectedMunicipality,
      );

      // Last resort only: fall back to cached marker points when no boundary
      // could be loaded (still never driven by the network).
      if (plan.source == 'fallback') {
        final localView = _preferredInitialView(barangayHalls, incidents);
        plan = MapCameraPlan(
          center: localView.$1,
          zoom: localView.$2,
          source: 'fallback',
        );
      }

      _defaultFitBounds = plan.fitBounds;
      _defaultFallbackCenter = plan.center;
      _defaultFallbackZoom = plan.zoom;

      if (mounted) {
        setState(() {
          kaliboBoundaries = renderKalibo;
          ibajayBoundaries = renderIbajay;
          autoHighlightName = highlightName;
          mapCenter = plan.center;
          initialZoom = plan.zoom;
          currentZoom = plan.zoom;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applyCameraPlan(plan);
        });
      }

      // Live marker data refreshed in the background. Never repositions the
      // camera, and a failure never replaces the offline base map or clears
      // the working cache.
      await _syncMarkers();
    } catch (error) {
      debugPrint('Map load failed (offline base map kept): $error');
      if (!mounted) return;
      setState(() {
        _markersLoading = false;
        _markersOffline = true;
        _markersFromCache = true;
      });
    }
  }

  void _applyCameraPlan(MapCameraPlan plan) {
    final fit = plan.fitBounds;
    if (fit != null) {
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: fit,
          padding: const EdgeInsets.all(24),
          maxZoom: 17,
        ),
      );
    } else {
      mapController.move(plan.center, plan.zoom);
    }
  }

  /// Fetches the live marker snapshot and, only after a complete valid
  /// response, replaces the SQLite cache and shows the live data. Any failure
  /// keeps whatever is currently displayed (cached markers).
  Future<void> _syncMarkers() async {
    if (_markerSyncInProgress) return;
    _markerSyncInProgress = true;
    try {
      final result = await _markerRepository.refresh(
        userId: AuthService.currentUserId ?? 0,
        role: AuthService.currentRole ?? widget.role,
        barangayId: AuthService.currentBarangayId,
        municipality: _selectedMunicipality,
        requestUserId: AuthService.currentUserId,
        requestMunicipality: _markerRequestMunicipality,
      );
      if (!mounted) return;

      if (result.offline) {
        _enterOfflineMarkersState();
        return;
      }

      setState(() {
        _applyMarkerData(result.data);
        _markersLoading = false;
        _markersOffline = false;
        _markersFromCache = false;
        _lastSyncedAt = result.lastUpdated;
      });
    } catch (error) {
      debugPrint('Marker sync failed (cache kept): $error');
      if (!mounted) return;
      _enterOfflineMarkersState();
    } finally {
      _markerSyncInProgress = false;
    }
  }

  /// Marks the marker layer as offline: current (cached) markers remain
  /// visible and the banner explains the saved snapshot state.
  void _enterOfflineMarkersState() {
    setState(() {
      _markersLoading = false;
      _markersOffline = true;
      _markersFromCache = true;
    });
  }

  /// Connectivity restored or app resumed → refresh markers in the background
  /// with the shared 3-second debounce (see [HotlineReconnectMixin]).
  @override
  void onNetworkRestored() {
    _syncMarkers();
  }

  void _applyMarkerData(Map<String, List<Map<String, dynamic>>> data) {
    barangayHalls = data['barangay_halls'] ?? [];
    evacuationCenters = data['evacuation_centers'] ?? [];
    pcfFacilities = data['pcf_facilities'] ?? [];
    incidents = data['incidents'] ?? [];
  }

  String get _markerStatusBanner {
    if (_markersLoading) return 'Loading live markers...';
    if (_lastSyncedAt == null) {
      return 'Marker data has not been saved on this device yet.';
    }
    return 'Showing saved markers • Last updated '
        '${_formatCacheTime(_lastSyncedAt!)}. Conditions may have changed.';
  }

  /// "Saved data" label shown only on cached markers so saved vs. live is
  /// always distinguishable.
  String _savedMarkerTag(String base) =>
      _markersFromCache ? 'Saved data • $base' : base;

  String _savedIncidentDetails(Map<String, dynamic> incident) {
    var details = _savedMarkerTag(
      '${incident['barangay_name'] ?? ''} • '
      '${incidentStatusLabel(
        incident['status']?.toString() ?? '',
        municipality: incident['municipality']?.toString(),
      )}',
    );
    if (_markersFromCache) {
      final created = incident['created_at']?.toString() ?? '';
      if (created.isNotEmpty) details += '\nRecord updated $created';
    }
    return details;
  }

  String _formatCacheTime(DateTime time) {
    final local = time.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  List<Polygon<String>> _buildBoundaryPolygons(
    List<MapBoundary> boundaries, {
    required bool isIbajayLayer,
  }) {
    final polygons = <Polygon<String>>[];
    final isPrimary = isIbajayLayer == isIbajayPrimary;

    for (final boundary in boundaries) {
      final name = boundary.name;
      final isAutoHighlighted =
          autoHighlightName.isNotEmpty &&
          name.trim().toLowerCase() == autoHighlightName.toLowerCase();
      final isEmphasized = isSelected(name) || isAutoHighlighted;

      final Color fillColor;
      final Color borderColor;
      final double strokeWidth;

      if (isEmphasized) {
        fillColor = AppColors.primaryRed.withValues(alpha: 0.5);
        borderColor = AppColors.primaryRed;
        strokeWidth = 3;
      } else if (isIbajayLayer) {
        final color = AppColors.primaryRed;
        fillColor = color.withValues(alpha: isPrimary ? 0.10 : 0.06);
        borderColor = color.withValues(alpha: isPrimary ? 0.55 : 0.4);
        strokeWidth = isPrimary ? 1.6 : 1.0;
      } else if (isIbajayPrimary) {
        fillColor = Colors.blueGrey.withValues(alpha: 0.04);
        borderColor = Colors.blueGrey.withValues(alpha: 0.35);
        strokeWidth = 1.6;
      } else {
        final colorSeed = name.hashCode.abs();
        final base = Colors.primaries[colorSeed % Colors.primaries.length];
        fillColor = base.withValues(alpha: 0.09);
        borderColor = base.withValues(alpha: 0.52);
        strokeWidth = 1.6;
      }

      for (final ring in boundary.rings) {
        if (ring.length < 3) continue;
        polygons.add(
          Polygon<String>(
            points: ring,
            color: fillColor,
            borderColor: borderColor,
            borderStrokeWidth: strokeWidth,
            hitValue: name,
          ),
        );
      }
    }
    return polygons;
  }

  bool isSelected(String name) => selectedPolygonName == name;

  /// Red-shades the tapped boundary, mirroring the web's selected style, and
  /// zooms/pans the camera to it (the web's selectBarangay(name, true) fit).
  /// A tap on a boundary toggles/selects it; an empty tap clears it. Camera
  /// is left untouched when deselecting or tapping empty space.
  void _onMapTap(LatLng point) {
    String? hit;
    for (final layer in <List<MapBoundary>>[
      ibajayBoundaries,
      kaliboBoundaries,
    ]) {
      for (final boundary in layer) {
        for (final ring in boundary.rings) {
          if (_pointInRing(point, ring)) {
            hit = boundary.name;
            break;
          }
        }
        if (hit != null) break;
      }
      if (hit != null) break;
    }

    final previous = selectedPolygonName;
    final selected = (hit == null || hit == previous) ? null : hit;

    setState(() {
      selectedPolygonName = selected;
    });

    if (selected == null) return;

    for (final layer in <List<MapBoundary>>[
      ibajayBoundaries,
      kaliboBoundaries,
    ]) {
      for (final boundary in layer) {
        if (boundary.name != selected) continue;
        final bounds = _boundsForBoundary(boundary);
        if (bounds != null) {
          mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
          );
        }
        return;
      }
    }
  }

  /// Bounding box spanning every ring of a boundary (Polygon/MultiPolygon),
  /// using the shared expand logic from [_expandBounds].
  LatLngBounds? _boundsForBoundary(MapBoundary boundary) {
    LatLngBounds? bounds;
    for (final ring in boundary.rings) {
      for (final p in ring) {
        bounds = _expandBounds(bounds, p);
      }
    }
    return bounds;
  }

  /// Expands [bounds] to include [p]; seeds a new bounds when [bounds] is null.
  LatLngBounds _expandBounds(LatLngBounds? bounds, LatLng p) {
    if (bounds == null) return LatLngBounds(p, p);
    final swLat = math.min(bounds.south, p.latitude);
    final swLng = math.min(bounds.west, p.longitude);
    final neLat = math.max(bounds.north, p.latitude);
    final neLng = math.max(bounds.east, p.longitude);
    return LatLngBounds(LatLng(swLat, swLng), LatLng(neLat, neLng));
  }

  /// Restores the default view the screen loaded with — the web's "Reset Map"
  /// button. The polygon selection is left as-is.
  void _resetMapView() {
    if (!mounted) return;
    final fit = _defaultFitBounds;
    if (fit != null) {
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: fit,
          padding: const EdgeInsets.all(24),
          maxZoom: 17,
        ),
      );
    } else {
      mapController.move(_defaultFallbackCenter, _defaultFallbackZoom);
    }
  }

  /// Ray-casting point-in-polygon test on a boundary ring.
  bool _pointInRing(LatLng point, List<LatLng> ring) {
    var inside = false;
    for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].latitude, yi = ring[i].longitude;
      final xj = ring[j].latitude, yj = ring[j].longitude;
      final intersects =
          ((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude <
              (xj - xi) * (point.longitude - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  LatLng? _latLngFrom(Map<String, dynamic> item) {
    final lat = _toDouble(item['latitude']);
    final lng = _toDouble(item['longitude']);
    if (lat == null || lng == null) return null;
    if (lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  (LatLng, double) _preferredInitialView(
    List<Map<String, dynamic>> halls,
    List<Map<String, dynamic>> loadedIncidents,
  ) {
    final role = (AuthService.currentRole ?? widget.role).toLowerCase();

    if (role == 'barangay' || role == 'brgy') {
      final currentBarangayId = AuthService.currentBarangayId;
      final currentBarangayName = (AuthService.currentBarangayName ?? '')
          .toLowerCase()
          .trim();

      for (final hall in halls) {
        final id = int.tryParse(hall['id']?.toString() ?? '');
        final name = hall['name']?.toString().toLowerCase().trim() ?? '';
        final point = _latLngFrom(hall);

        if (point != null &&
            (id == currentBarangayId ||
                (currentBarangayName.isNotEmpty &&
                    name == currentBarangayName))) {
          return (point, 15.4);
        }
      }

      for (final incident in loadedIncidents) {
        final id = int.tryParse(incident['barangay_id']?.toString() ?? '');
        final name =
            incident['barangay_name']?.toString().toLowerCase().trim() ?? '';
        final point = _latLngFrom(incident);

        if (point != null &&
            (id == currentBarangayId ||
                (currentBarangayName.isNotEmpty &&
                    name == currentBarangayName))) {
          return (point, 15.4);
        }
      }
    }

    for (final incident in loadedIncidents) {
      final point = _latLngFrom(incident);
      if (point != null) {
        return (point, 14.5);
      }
    }

    for (final hall in halls) {
      final point = _latLngFrom(hall);
      if (point != null) {
        return (point, 12.8);
      }
    }

    return (isIbajayPrimary ? ibajayCenter : kaliboCenter, 12.4);
  }

  void _showMarkerInfo(String title, String details) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title\n$details'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  double get markerSize {
    if (currentZoom >= 16) return 46;
    if (currentZoom >= 14) return 38;
    return 28;
  }

  double get markerIconSize {
    if (currentZoom >= 16) return 25;
    if (currentZoom >= 14) return 22;
    return 16;
  }

  Marker _buildMarker({
    required LatLng point,
    required IconData icon,
    required Color color,
    required String title,
    required String details,
  }) {
    final size = markerSize;
    return Marker(
      point: point,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _showMarkerInfo(title, details),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: currentZoom >= 14 ? 2 : 1.4,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 4),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: markerIconSize),
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (showBarangayHalls) {
      for (final hall in barangayHalls) {
        final point = _latLngFrom(hall);
        if (point == null) continue;
        markers.add(
          _buildMarker(
            point: point,
            icon: Icons.account_balance,
            color: AppColors.primaryBlue,
            title: hall['name']?.toString() ?? 'Barangay Hall',
            details: _savedMarkerTag('Barangay Hall'),
          ),
        );
      }
    }

    if (showEvacuationCenters) {
      for (final center in evacuationCenters) {
        final point = _latLngFrom(center);
        if (point == null) continue;
        markers.add(
          _buildMarker(
            point: point,
            icon: Icons.location_city,
            color: AppColors.successGreen,
            title: center['center_name']?.toString() ?? 'Evacuation Center',
            details: _savedMarkerTag('Barangay ${center['barangay'] ?? ''}'),
          ),
        );
      }
    }

    if (showPcfFacilities) {
      for (final facility in pcfFacilities) {
        final point = _latLngFrom(facility);
        if (point == null) continue;
        markers.add(
          _buildMarker(
            point: point,
            icon: Icons.local_hospital,
            color: AppColors.primaryPurple,
            title: facility['name']?.toString() ?? 'Primary Care Facility',
            details: _savedMarkerTag(
              'Primary Care Facility • ${facility['municipality'] ?? ''}',
            ),
          ),
        );
      }
    }

    if (showIncidents) {
      for (final incident in incidents) {
        final point = _latLngFrom(incident);
        if (point == null) continue;
        final status = incident['status']?.toString() ?? '';
        final isMdrStatus = _mdrStatuses.contains(status);

        // Governor (pho) only: MDR-level incidents live in the optional
        // orange layer. Every other role keeps the legacy behavior — all
        // returned incidents render red under showIncidents.
        if (isMdrStatus && _isPhoRole) {
          if (!showMdrEscalations) continue;
          markers.add(
            _buildMarker(
              point: point,
              icon: Icons.warning_amber,
              color: AppColors.primaryOrange,
              title: incident['disaster_type']?.toString() ?? 'Incident',
              details: _savedIncidentDetails(incident),
            ),
          );
          continue;
        }

        markers.add(
          _buildMarker(
            point: point,
            icon: Icons.warning_amber,
            color: AppColors.primaryRed,
            title: incident['disaster_type']?.toString() ?? 'Incident',
            details: _savedIncidentDetails(incident),
          ),
        );
      }
    }

    return markers;
  }

  Widget _layerToggle({
    required bool value,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: value
                ? color
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: value ? color : Theme.of(context).dividerColor,
            ),
          ),
          child: Icon(icon, color: value ? Colors.white : color, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();
    final cardColor = Theme.of(
      context,
    ).colorScheme.surface.withValues(alpha: 0.78);
    final barangayPolygons = _buildBoundaryPolygons(
      kaliboBoundaries,
      isIbajayLayer: false,
    );
    final ibajayPolygonLayer = _buildBoundaryPolygons(
      ibajayBoundaries,
      isIbajayLayer: true,
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: initialZoom,
            minZoom: 10,
            maxZoom: 18,
            onTap: (tapPosition, latLng) => _onMapTap(latLng),
            onPositionChanged: (camera, hasGesture) {
              if ((camera.zoom - currentZoom).abs() >= 0.15) {
                setState(() => currentZoom = camera.zoom);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.saster.app',
            ),
            const OfflineMapLayer(),
            if (barangayPolygons.isNotEmpty)
              PolygonLayer(polygons: barangayPolygons),
            if (ibajayPolygonLayer.isNotEmpty)
              PolygonLayer(polygons: ibajayPolygonLayer),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
        if (_markersLoading || _markersOffline)
          Positioned(
            top: 12,
            left: 12,
            right: 64,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_markersLoading) ...[
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            _markerStatusBanner,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Material(
            color: cardColor,
            elevation: 3,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _layerToggle(
                    value: showBarangayHalls,
                    icon: Icons.account_balance,
                    color: AppColors.primaryBlue,
                    tooltip: 'Barangay Halls',
                    onTap: () =>
                        setState(() => showBarangayHalls = !showBarangayHalls),
                  ),
                  const SizedBox(width: 6),
                  _layerToggle(
                    value: showEvacuationCenters,
                    icon: Icons.location_city,
                    color: AppColors.successGreen,
                    tooltip: 'Evacuation Centers',
                    onTap: () => setState(
                      () => showEvacuationCenters = !showEvacuationCenters,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _layerToggle(
                    value: showPcfFacilities,
                    icon: Icons.local_hospital,
                    color: AppColors.primaryPurple,
                    tooltip: 'Primary Care Facilities',
                    onTap: () =>
                        setState(() => showPcfFacilities = !showPcfFacilities),
                  ),
                  const SizedBox(width: 6),
                  _layerToggle(
                    value: showIncidents,
                    icon: Icons.warning_amber,
                    color: AppColors.primaryRed,
                    tooltip: 'Incidents',
                    onTap: () => setState(() => showIncidents = !showIncidents),
                  ),
                  if (_isPhoRole) ...[
                    const SizedBox(width: 6),
                    _layerToggle(
                      value: showMdrEscalations,
                      icon: Icons.forward_to_inbox,
                      color: AppColors.primaryOrange,
                      tooltip: 'Forwarded to MDR',
                      onTap: () => setState(
                        () => showMdrEscalations = !showMdrEscalations,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'refresh-map-${widget.role}',
            // Refresh markers only — the camera is never re-positioned by a
            // marker refresh, connectivity restore, or background sync.
            onPressed: _syncMarkers,
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            child: const Icon(Icons.refresh),
          ),
        ),
        Positioned(
          top: 62,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'reset-map-${widget.role}',
            tooltip: 'Reset Map',
            onPressed: _resetMapView,
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }
}
