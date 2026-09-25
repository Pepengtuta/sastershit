import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/app_colors.dart';
import '../../constants/disaster_type_config.dart';
import '../../services/auth_service.dart';
import '../../services/evacuation_center_service.dart';
import '../../services/incident_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/info_card.dart';
import '../../widgets/offline_map_layer.dart';
import '../../widgets/section_title.dart';

class EditIncidentScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const EditIncidentScreen({super.key, required this.report});

  @override
  State<EditIncidentScreen> createState() => _EditIncidentScreenState();
}

class _EditIncidentScreenState extends State<EditIncidentScreen> {
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  final mapController = MapController();

  final affectedController = TextEditingController(text: '0');
  final injuredController = TextEditingController(text: '0');
  final deadController = TextEditingController(text: '0');
  final missingController = TextEditingController(text: '0');
  final descriptionController = TextEditingController();
  final exactLocationController = TextEditingController();
  final otherAssistanceController = TextEditingController();
  final evacHouseholdsController = TextEditingController(text: '0');
  final evacAdultsController = TextEditingController(text: '0');
  final evacChildrenController = TextEditingController(text: '0');
  final evacMembersController = TextEditingController(text: '0');
  final roadLocationController = TextEditingController();

  String? selectedDisasterType;
  String evacuationNeeded = 'No';
  int? selectedEvacuationCenterId;
  DateTime incidentDateTime = DateTime.now();
  String roadStatus = 'Passable';
  final Set<String> selectedRoadBlockageCauses = {};

  LatLng incidentLocation = const LatLng(11.7069, 122.3644);
  String locationSource = 'Saved report location';

  bool isSubmitting = false;
  bool isLoadingCenters = true;
  bool isLoadingLocation = false;
  List<dynamic> centers = [];
  List<XFile> evidenceFiles = [];
  List<Polygon> barangayPolygons = [];
  List<Polygon> ibajayPurokPolygons = [];
  final List<Map<String, dynamic>> _ownBoundaryGeometries = [];

  final LatLng ibajayCenter = const LatLng(11.7331, 122.1590);

  bool get isIbajayPrimary =>
      (AuthService.currentMunicipality ?? 'Kalibo').toLowerCase() == 'ibajay';

  int reportId = 0;

  final List<String> baseDisasterTypes = const [
    'Typhoon',
    'Flood',
    'Storm Surge',
    'Earthquake',
    'Landslide',
    'Fire',
    'Drought / El Niño',
    'Disease Outbreak',
    'Accident / Mass Casualty Incident',
    'Others',
  ];

  final List<String> assistanceOptions = const [
    'Medical Team',
    'Water',
    'Clearing Operations',
    'Rescue Team',
    'Ambulance',
    'Food Packs',
    'Shelter',
    'Other',
  ];

  final List<String> roadStatusOptions = const [
    'Passable',
    'Partially Passable',
    'Obstructed',
  ];

  final List<String> roadBlockageOptions = const [
    'Fallen Tree',
    'Downed Power Line / Electric Post',
    'Flooding / Deep Water',
    'Landslide / Debris / Mud',
    'Damaged / Collapsed Bridge',
    'Other / Cannot Inspect',
  ];

  final Set<String> selectedAssistance = {};

  @override
  void initState() {
    super.initState();
    prefillFromReport();
    loadCenters();
    _loadBarangayPolygons();
    _loadIbajayPuroks();
  }

  @override
  void dispose() {
    affectedController.dispose();
    injuredController.dispose();
    deadController.dispose();
    missingController.dispose();
    descriptionController.dispose();
    exactLocationController.dispose();
    otherAssistanceController.dispose();
    evacHouseholdsController.dispose();
    evacAdultsController.dispose();
    evacChildrenController.dispose();
    evacMembersController.dispose();
    roadLocationController.dispose();
    super.dispose();
  }

  double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<void> _loadBarangayPolygons() async {
    try {
      final raw = await rootBundle.loadString('assets/data/kalibo_barangays.geojson');
      final geojson = jsonDecode(raw) as Map<String, dynamic>;
      final features = (geojson['features'] as List?) ?? [];
      final polygons = <Polygon>[];
      for (final feature in features) {
        final f = Map<String, dynamic>.from(feature as Map);
        final geometry = Map<String, dynamic>.from((f['geometry'] ?? {}) as Map);
        final properties = Map<String, dynamic>.from((f['properties'] ?? {}) as Map);
        final name = properties['adm4_en']?.toString() ?? properties['name']?.toString() ?? properties['NAME_3']?.toString() ?? '';
        final type = geometry['type']?.toString();
        final coordinates = geometry['coordinates'];
        if (!isIbajayPrimary && _isCurrentBarangay(name)) {
          _ownBoundaryGeometries.add(Map<String, dynamic>.from(geometry));
        }
        final Color fillColor;
        final Color borderColor;
        if (isIbajayPrimary) {
          fillColor = Colors.blueGrey.withValues(alpha: 0.04);
          borderColor = Colors.blueGrey.withValues(alpha: 0.35);
        } else {
          final colorSeed = name.hashCode.abs();
          fillColor = Colors.primaries[colorSeed % Colors.primaries.length].withValues(alpha: 0.09);
          borderColor = Colors.primaries[colorSeed % Colors.primaries.length].withValues(alpha: 0.52);
        }
        if (type == 'Polygon' && coordinates is List) {
          final points = _pointsFromRing(coordinates.first as List);
          if (points.length >= 3) {
            polygons.add(Polygon(points: points, color: fillColor, borderColor: borderColor, borderStrokeWidth: 1.6));
          }
        }
        if (type == 'MultiPolygon' && coordinates is List) {
          for (final polygon in coordinates) {
            if (polygon is List && polygon.isNotEmpty) {
              final points = _pointsFromRing(polygon.first as List);
              if (points.length >= 3) {
                polygons.add(Polygon(points: points, color: fillColor, borderColor: borderColor, borderStrokeWidth: 1.6));
              }
            }
          }
        }
      }
      if (mounted) setState(() => barangayPolygons = polygons);
    } catch (_) {}
  }

  Future<void> _loadIbajayPuroks() async {
    try {
      final raw = await rootBundle.loadString('assets/data/ibajay_puroks.geojson');
      final geojson = jsonDecode(raw) as Map<String, dynamic>;
      final features = (geojson['features'] as List?) ?? [];
      final polygons = <Polygon>[];
      final ibajayColor = AppColors.primaryRed;
      final primary = isIbajayPrimary;
      for (final feature in features) {
        final f = Map<String, dynamic>.from(feature as Map);
        final geometry = Map<String, dynamic>.from((f['geometry'] ?? {}) as Map);
        final properties = Map<String, dynamic>.from((f['properties'] ?? {}) as Map);
        if (properties['level']?.toString() == 'municipality') continue;
        if (isIbajayPrimary && _isCurrentBarangay(properties['name']?.toString() ?? '')) {
          _ownBoundaryGeometries.add(Map<String, dynamic>.from(geometry));
        }
        final type = geometry['type']?.toString();
        final coordinates = geometry['coordinates'];
        if (type == 'Polygon' && coordinates is List) {
          final points = _pointsFromRing(coordinates.first as List);
          if (points.length >= 3) {
            polygons.add(Polygon(
                points: points,
                color: ibajayColor.withValues(alpha: primary ? 0.10 : 0.06),
                borderColor: ibajayColor.withValues(alpha: primary ? 0.55 : 0.4),
                borderStrokeWidth: primary ? 1.6 : 1.0));
          }
        }
      }
      if (mounted) setState(() => ibajayPurokPolygons = polygons);
    } catch (_) {}
  }

  List<LatLng> _pointsFromRing(List ring) {
    final points = <LatLng>[];
    for (final pair in ring) {
      if (pair is List && pair.length >= 2) {
        final lng = toDouble(pair[0]);
        final lat = toDouble(pair[1]);
        if (lat != null && lng != null) points.add(LatLng(lat, lng));
      }
    }
    return points;
  }

  bool _isCurrentBarangay(String name) {
    final current = AuthService.currentBarangayName ?? '';
    return current.trim().isNotEmpty && name.trim().toLowerCase() == current.trim().toLowerCase();
  }

  // Dart mirror of point_in_pin_ring / point_in_rings / point_in_rings_tolerance
  // in app/includes/functions.php: same ray-casting rule, outer rings only,
  // same 0.0001 degree (~11 m) boundary tolerance so the app warning matches
  // the server's pin_outside_area flag.
  bool _pointInRing(double lat, double lng, List ring) {
    bool inside = false;
    for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i] as List;
      final b = ring[j] as List;
      final xi = (a[0] as num).toDouble(), yi = (a[1] as num).toDouble();
      final xj = (b[0] as num).toDouble(), yj = (b[1] as num).toDouble();
      if (((yi > lat) != (yj > lat)) && (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  bool _pointInOuterRings(double lat, double lng, Map<String, dynamic> geometry) {
    final type = geometry['type']?.toString();
    final coords = geometry['coordinates'];
    if (coords is! List) return false;
    final ringSets = type == 'MultiPolygon' ? coords : [coords];
    for (final rs in ringSets) {
      if (rs is! List || rs.isEmpty) continue;
      final outer = rs.first;
      if (outer is! List || outer.length < 3) continue;
      if (_pointInRing(lat, lng, outer)) return true;
    }
    return false;
  }

  bool _pinWithinBoundary() {
    if (_ownBoundaryGeometries.isEmpty) return true;
    const double eps = 0.0001;
    final lat = incidentLocation.latitude;
    final lng = incidentLocation.longitude;
    for (final geometry in _ownBoundaryGeometries) {
      if (_pointInOuterRings(lat, lng, geometry)) return true;
      if (_pointInOuterRings(lat + eps, lng, geometry)) return true;
      if (_pointInOuterRings(lat - eps, lng, geometry)) return true;
      if (_pointInOuterRings(lat, lng + eps, geometry)) return true;
      if (_pointInOuterRings(lat, lng - eps, geometry)) return true;
    }
    return false;
  }

  void prefillFromReport() {
    final report = widget.report;
    reportId = toInt(report['id']) ?? 0;

    selectedDisasterType = report['disaster_type']?.toString();
    if (selectedDisasterType != null && selectedDisasterType!.isEmpty) {
      selectedDisasterType = null;
    }

    evacuationNeeded = (report['evacuation_needed']?.toString() == 'Yes') ? 'Yes' : 'No';
    selectedEvacuationCenterId = toInt(report['evacuation_center_id']);

    affectedController.text = (toInt(report['affected_people']) ?? 0).toString();
    injuredController.text = (toInt(report['injured']) ?? 0).toString();
    deadController.text = (toInt(report['dead']) ?? 0).toString();
    missingController.text = (toInt(report['missing']) ?? 0).toString();
    evacHouseholdsController.text = (toInt(report['evac_households']) ?? 0).toString();
    evacAdultsController.text = (toInt(report['evac_adults']) ?? 0).toString();
    evacChildrenController.text = (toInt(report['evac_children']) ?? 0).toString();
    evacMembersController.text = (toInt(report['evac_members']) ?? 0).toString();

    descriptionController.text = report['description']?.toString() ?? '';
    exactLocationController.text = report['exact_location']?.toString() ?? '';

    roadStatus = report['road_status']?.toString() ?? 'Passable';
    if (!roadStatusOptions.contains(roadStatus)) roadStatus = 'Passable';
    roadLocationController.text = report['road_location']?.toString() ?? '';

    final causesRaw = report['road_blockage_causes']?.toString() ?? '';
    if (causesRaw.trim().isNotEmpty) {
      for (final cause in causesRaw.split(',')) {
        final trimmed = cause.trim();
        if (roadBlockageOptions.contains(trimmed)) {
          selectedRoadBlockageCauses.add(trimmed);
        }
      }
    }

    final dtRaw = report['incident_datetime']?.toString();
    if (dtRaw != null && dtRaw.trim().isNotEmpty && dtRaw != 'null') {
      final parsed = DateTime.tryParse(dtRaw.trim().replaceFirst(' ', 'T'));
      if (parsed != null) incidentDateTime = parsed;
    }

    final lat = toDouble(report['latitude']);
    final lng = toDouble(report['longitude']);
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      incidentLocation = LatLng(lat, lng);
      locationSource = 'Saved report location';
    }

    prefillAssistance(report['assistance_needed']?.toString() ?? '');
  }

  void prefillAssistance(String raw) {
    if (raw.trim().isEmpty) return;
    final tokens = raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
    final leftovers = <String>[];

    for (final token in tokens) {
      if (token != 'Other' && assistanceOptions.contains(token)) {
        selectedAssistance.add(token);
      } else if (token.toLowerCase().startsWith('other')) {
        selectedAssistance.add('Other');
        final idx = token.indexOf(':');
        if (idx >= 0 && idx + 1 < token.length) {
          leftovers.add(token.substring(idx + 1).trim());
        }
      } else {
        leftovers.add(token);
      }
    }

    if (leftovers.isNotEmpty) {
      selectedAssistance.add('Other');
      otherAssistanceController.text = leftovers.join(', ');
    }
  }

  List<String> get effectiveDisasterTypes {
    final list = List<String>.from(baseDisasterTypes);
    final stored = selectedDisasterType;
    if (stored != null && stored.isNotEmpty && !list.contains(stored)) {
      list.insert(0, stored);
    }
    return list;
  }

  Future<void> loadCenters() async {
    final result = await EvacuationCenterService.getEvacuationCenters(
      role: 'barangay',
      barangayId: AuthService.currentBarangayId,
      barangayName: AuthService.currentBarangayName,
    );

    if (!mounted) return;

    setState(() {
      isLoadingCenters = false;
      centers = result['success'] == true ? (result['data'] ?? []) : [];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mapController.move(incidentLocation, 16);
    });
  }

  List<Map<String, dynamic>> _uniqueEvacuationCenters() {
    final seenIds = <int>{};
    final unique = <Map<String, dynamic>>[];

    // Keep the report's currently-selected center available even if it is no
    // longer in the active list returned by the service.
    if (selectedEvacuationCenterId != null && selectedEvacuationCenterId! > 0) {
      seenIds.add(selectedEvacuationCenterId!);
      unique.add({
        'id': selectedEvacuationCenterId,
        'center_name': widget.report['evacuation_center_name']?.toString() ?? 'Currently selected center',
      });
    }

    for (final item in centers) {
      if (item is! Map) continue;
      final center = Map<String, dynamic>.from(item);
      final id = int.tryParse(center['id']?.toString() ?? '') ?? 0;

      if (id <= 0 || seenIds.contains(id)) continue;
      seenIds.add(id);
      unique.add(center);
    }

    return unique;
  }

  Future<void> useDeviceLocation() async {
    setState(() => isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      if (!mounted) return;

      setState(() {
        incidentLocation = LatLng(position.latitude, position.longitude);
        locationSource = 'Device current location';
        isLoadingLocation = false;
      });

      mapController.move(incidentLocation, 16);
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingLocation = false);
    }
  }

  String formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:00';
  }

  String displayDateTime(DateTime value) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour12 = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    final minute = value.minute.toString().padLeft(2, '0');
    return '${months[value.month - 1]} ${value.day}, ${value.year} • $hour12:$minute $ampm';
  }

  Future<void> pickIncidentDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: incidentDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(incidentDateTime),
    );

    if (pickedTime == null) return;

    setState(() {
      incidentDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> pickEvidence(ImageSource source, {bool video = false}) async {
    final int photoCount = evidenceFiles.where((f) {
      final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
      return {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext);
    }).length;
    final int videoCount = evidenceFiles.where((f) {
      final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
      return {'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(ext);
    }).length;

    if (video && videoCount >= 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 2 videos per report.'), backgroundColor: AppColors.primaryRed),
        );
      }
      return;
    }
    if (!video && photoCount >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 5 photos per report.'), backgroundColor: AppColors.primaryRed),
        );
      }
      return;
    }

    final file = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;

    final length = await file.length();
    if (video && length > 50 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video exceeds 50 MB limit.'), backgroundColor: AppColors.primaryRed),
        );
      }
      return;
    }
    if (!video && length > 15 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo exceeds 15 MB limit.'), backgroundColor: AppColors.primaryRed),
        );
      }
      return;
    }

    setState(() => evidenceFiles.add(file));
  }

  String assistanceNeededText() {
    final values = selectedAssistance.where((item) => item != 'Other').toList();
    if (selectedAssistance.contains('Other')) {
      final other = otherAssistanceController.text.trim();
      values.add(other.isEmpty ? 'Other' : 'Other: $other');
    }
    return values.join(', ');
  }

  Future<void> submitReport() async {
    if (!formKey.currentState!.validate()) return;

    if (!_pinWithinBoundary()) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Location outside boundary'),
          content: Text(
            'The selected location appears to be outside the '
            '${AuthService.currentBarangayName ?? 'selected barangay'} boundary. '
            'The report can still be saved, but it will be marked for review. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit anyway', style: TextStyle(color: AppColors.primaryRed)),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final userId = AuthService.currentUserId;
    final barangayId = AuthService.currentBarangayId;

    if (userId == null || barangayId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login session missing. Please login again.'), backgroundColor: AppColors.primaryRed),
      );
      return;
    }

    if (reportId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing report reference.'), backgroundColor: AppColors.primaryRed),
      );
      return;
    }

    setState(() => isSubmitting = true);

    final updateResult = await IncidentService.updateIncident(
      reportId: reportId,
      userId: userId,
      barangayId: barangayId,
      disasterType: selectedDisasterType!,
      evacuationNeeded: evacuationNeeded,
      evacuationCenterId: selectedEvacuationCenterId,
      evacHouseholds: int.tryParse(evacHouseholdsController.text.trim()) ?? 0,
      evacAdults: int.tryParse(evacAdultsController.text.trim()) ?? 0,
      evacChildren: int.tryParse(evacChildrenController.text.trim()) ?? 0,
      evacMembers: int.tryParse(evacMembersController.text.trim()) ?? 0,
      incidentDatetime: formatDateTime(incidentDateTime),
      description: descriptionController.text.trim(),
      latitude: incidentLocation.latitude,
      longitude: incidentLocation.longitude,
      exactLocation: exactLocationController.text.trim(),
      assistanceNeeded: assistanceNeededText(),
      roadStatus: roadStatus,
      roadBlockageCauses: selectedRoadBlockageCauses.join(', '),
      roadLocation: roadLocationController.text.trim(),
      affectedPeople: int.tryParse(affectedController.text.trim()) ?? 0,
      injured: int.tryParse(injuredController.text.trim()) ?? 0,
      dead: int.tryParse(deadController.text.trim()) ?? 0,
      missing: int.tryParse(missingController.text.trim()) ?? 0,
    );

    if (!mounted) return;

    if (updateResult['success'] != true) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updateResult['message']?.toString() ?? 'Failed to update incident.'), backgroundColor: AppColors.primaryRed),
      );
      return;
    }

    if (evidenceFiles.isNotEmpty) {
      final uploadResult = await IncidentService.uploadEvidence(incidentId: reportId, uploadedBy: userId, files: evidenceFiles);
      if (uploadResult['success'] != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uploadResult['message']?.toString() ?? 'Report updated but new evidence upload failed.'), backgroundColor: AppColors.warningYellow),
        );
      }
    }

    if (!mounted) return;
    setState(() => isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incident report updated successfully.'), backgroundColor: AppColors.successGreen),
    );
    Navigator.pop(context, true);
  }

  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primaryRed, width: 2), borderRadius: BorderRadius.circular(14)),
    );
  }

  Color _roadStatusColor(String status) {
    switch (status) {
      case 'Partially Passable':
        return AppColors.warningYellow;
      case 'Obstructed':
        return AppColors.primaryRed;
      default:
        return AppColors.successGreen;
    }
  }

  Widget numberField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextFormField(
      controller: controller,
      enabled: !isSubmitting,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: fieldDecoration(label, icon),
      validator: (value) {
        final number = int.tryParse(value?.trim() ?? '');
        if (number == null || number < 0) return 'Enter valid number';
        return null;
      },
    );
  }

  Widget responsiveTwoFields({required Widget first, required Widget second}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }
        return Row(children: [Expanded(child: first), const SizedBox(width: 12), Expanded(child: second)]);
      },
    );
  }

  Widget buildLocationPicker() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The marker starts on this report\u2019s saved location. Tap the map to move it, or use the location button for your current device location.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 260,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: incidentLocation,
                  initialZoom: 16,
                  minZoom: 11,
                  maxZoom: 18,
                  onTap: (tapPosition, point) {
                    if (isSubmitting) return;
                    setState(() {
                      incidentLocation = point;
                      locationSource = 'Selected on map';
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.saster.app',
                  ),
                  const OfflineMapLayer(),
                  PolygonLayer(polygons: barangayPolygons),
                  if (ibajayPurokPolygons.isNotEmpty) PolygonLayer(polygons: ibajayPurokPolygons),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: incidentLocation,
                        radius: 100,
                        useRadiusInMeter: true,
                        color: AppColors.primaryRed.withValues(alpha: 0.12),
                        borderColor: AppColors.primaryRed,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: incidentLocation,
                        width: 46,
                        height: 46,
                        child: const Icon(Icons.location_pin, color: AppColors.primaryRed, size: 46),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  isLoadingLocation
                      ? 'Getting device location...'
                      : '$locationSource • ${incidentLocation.latitude.toStringAsFixed(6)}, ${incidentLocation.longitude.toStringAsFixed(6)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Use device location',
                onPressed: isSubmitting ? null : () => useDeviceLocation(),
                icon: const Icon(Icons.my_location_outlined, color: AppColors.primaryRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildAssistanceNeeded() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: assistanceOptions.map((option) {
              final selected = selectedAssistance.contains(option);
              return FilterChip(
                selected: selected,
                label: Text(option),
                onSelected: isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          if (value) {
                            selectedAssistance.add(option);
                          } else {
                            selectedAssistance.remove(option);
                          }
                        });
                      },
              );
            }).toList(),
          ),
          if (selectedAssistance.contains('Other')) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: otherAssistanceController,
              enabled: !isSubmitting,
              decoration: fieldDecoration('Other Assistance Needed', Icons.edit_note_outlined),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildExistingAttachments() {
    return InfoCard(
      child: FutureBuilder<Map<String, dynamic>>(
        future: IncidentService.getReportAttachments(reportId: reportId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
            );
          }

          if (!snapshot.hasData || snapshot.data?['success'] != true) {
            return Text(snapshot.data?['message']?.toString() ?? 'Unable to load current attachments.');
          }

          final files = List<dynamic>.from(snapshot.data?['data'] ?? []);
          if (files.isEmpty) return const Text('No existing attachments.');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('These stay attached. You can add more below.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              ...files.map((item) {
                final file = Map<String, dynamic>.from(item);
                final type = file['file_type']?.toString().toLowerCase() ?? '';
                final name = file['file_name']?.toString() ?? 'Attachment';
                final isVideo = type.contains('video');
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(isVideo ? Icons.videocam_outlined : Icons.image_outlined, color: AppColors.primaryRed),
                  title: Text(name, overflow: TextOverflow.ellipsis),
                  subtitle: Text(isVideo ? 'Video evidence' : 'Photo evidence'),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barangayName = AuthService.currentBarangayName ?? 'Barangay';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Incident')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Disaster Report', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Editing as $barangayName • allowed while status is Pending', style: const TextStyle(color: AppColors.lightRed)),
                  ],
                ),
              ),
              const SectionTitle(title: 'Incident Date and Time'),
              InfoCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined, color: AppColors.primaryRed),
                  title: Text(displayDateTime(incidentDateTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Tap to edit date and time'),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: isSubmitting ? null : pickIncidentDateTime,
                ),
              ),
              const SectionTitle(title: 'Incident Location'),
              buildLocationPicker(),
              const SectionTitle(title: 'Incident Information'),
              DropdownButtonFormField<String>(
                value: selectedDisasterType,
                isExpanded: true,
                decoration: fieldDecoration('Disaster Type', Icons.warning_amber_outlined),
                items: effectiveDisasterTypes.map((type) {
                  final color = DisasterTypeConfig.getIconColor(type);
                  return DropdownMenuItem(value: type, child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(type, overflow: TextOverflow.ellipsis)),
                  ]));
                }).toList(),
                onChanged: isSubmitting ? null : (value) => setState(() => selectedDisasterType = value),
                validator: (value) => value == null || value.isEmpty ? 'Please select disaster type' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: evacuationNeeded,
                isExpanded: true,
                decoration: fieldDecoration('Evacuation Needed', Icons.location_city_outlined),
                items: const [DropdownMenuItem(value: 'No', child: Text('No')), DropdownMenuItem(value: 'Yes', child: Text('Yes'))],
                onChanged: isSubmitting
                    ? null
                    : (value) => setState(() {
                          evacuationNeeded = value ?? 'No';
                          if (evacuationNeeded == 'No') selectedEvacuationCenterId = null;
                        }),
              ),
              if (evacuationNeeded == 'Yes') ...[
                const SizedBox(height: 14),
                if (isLoadingCenters)
                  const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                else if (_uniqueEvacuationCenters().isEmpty)
                  const InfoCard(
                    child: Text('No evacuation center is assigned to this barangay yet. You can still save this incident report.'),
                  )
                else
                  DropdownButtonFormField<int>(
                    value: selectedEvacuationCenterId,
                    isExpanded: true,
                    decoration: fieldDecoration('Evacuation Center', Icons.apartment_outlined),
                    items: _uniqueEvacuationCenters().map((center) {
                      final id = int.tryParse(center['id']?.toString() ?? '') ?? 0;
                      final name = center['center_name']?.toString() ?? center['name']?.toString() ?? 'Evacuation Center';
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: isSubmitting ? null : (value) => setState(() => selectedEvacuationCenterId = value),
                  ),
              ],
              if (evacuationNeeded == 'Yes' && selectedEvacuationCenterId != null) ...[
                const SectionTitle(title: 'Evacuation Headcount'),
                InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick headcount at the evacuation center.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                      const SizedBox(height: 14),
                      responsiveTwoFields(
                        first: numberField(controller: evacHouseholdsController, label: 'Households', icon: Icons.home_outlined),
                        second: numberField(controller: evacAdultsController, label: 'Adults', icon: Icons.person_outlined),
                      ),
                      const SizedBox(height: 14),
                      responsiveTwoFields(
                        first: numberField(controller: evacChildrenController, label: 'Children', icon: Icons.child_care_outlined),
                        second: numberField(controller: evacMembersController, label: 'Family Members', icon: Icons.family_restroom_outlined),
                      ),
                    ],
                  ),
                ),
              ],
              // DISABLED: Assistance Needed — to be moved to Municipal level
              // const SectionTitle(title: 'Assistance Needed'),
              // buildAssistanceNeeded(),
              const SectionTitle(title: 'Casualty / Affected Count'),
              responsiveTwoFields(
                first: numberField(controller: affectedController, label: 'Affected', icon: Icons.groups_outlined),
                second: numberField(controller: injuredController, label: 'Injured', icon: Icons.personal_injury_outlined),
              ),
              const SizedBox(height: 14),
              responsiveTwoFields(
                first: numberField(controller: deadController, label: 'Dead', icon: Icons.dangerous_outlined),
                second: numberField(controller: missingController, label: 'Missing', icon: Icons.person_search_outlined),
              ),
              const SectionTitle(title: 'Exact Location'),
              TextFormField(
                controller: exactLocationController,
                enabled: !isSubmitting,
                decoration: fieldDecoration('e.g., near the bridge, beside the church', Icons.location_on_outlined),
              ),
              const SectionTitle(title: 'Road / Bridge Accessibility'),
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tells Municipal / Provincial whether response and relief teams can reach the area.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: roadStatus,
                      isExpanded: true,
                      decoration: fieldDecoration('Road Status', Icons.route_outlined),
                      items: roadStatusOptions.map((option) {
                        final statusColor = _roadStatusColor(option);
                        return DropdownMenuItem(
                          value: option,
                          child: Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(option, overflow: TextOverflow.ellipsis)),
                          ]),
                        );
                      }).toList(),
                      onChanged: isSubmitting
                          ? null
                          : (value) => setState(() {
                                roadStatus = value ?? 'Passable';
                                if (roadStatus == 'Passable') selectedRoadBlockageCauses.clear();
                              }),
                    ),
                    if (roadStatus != 'Passable') ...[
                      const SizedBox(height: 14),
                      Text('Cause of Blockage', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: roadBlockageOptions.map((option) {
                          final selected = selectedRoadBlockageCauses.contains(option);
                          return FilterChip(
                            selected: selected,
                            label: Text(option),
                            onSelected: isSubmitting
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value) {
                                        selectedRoadBlockageCauses.add(option);
                                      } else {
                                        selectedRoadBlockageCauses.remove(option);
                                      }
                                    });
                                  },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: roadLocationController,
                      enabled: !isSubmitting,
                      decoration: fieldDecoration('Road / Bridge Name or Landmark (optional)', Icons.signpost_outlined),
                    ),
                  ],
                ),
              ),
              const SectionTitle(title: 'Description'),
              TextFormField(
                controller: descriptionController,
                enabled: !isSubmitting,
                minLines: 4,
                maxLines: 6,
                decoration: fieldDecoration('Describe what happened', Icons.description_outlined),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter incident description' : null,
              ),
              const SectionTitle(title: 'Current Attachments'),
              buildExistingAttachments(),
              const SectionTitle(title: 'Add Photo / Video Evidence'),
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(onPressed: isSubmitting ? null : () => pickEvidence(ImageSource.gallery), icon: const Icon(Icons.photo_outlined), label: const Text('Image')),
                        OutlinedButton.icon(onPressed: isSubmitting ? null : () => pickEvidence(ImageSource.gallery, video: true), icon: const Icon(Icons.videocam_outlined), label: const Text('Video')),
                        OutlinedButton.icon(onPressed: isSubmitting ? null : () => pickEvidence(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (evidenceFiles.isEmpty)
                      const Text('No new file selected.')
                    else
                      ...evidenceFiles.map((file) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.attach_file, color: AppColors.primaryRed),
                            title: Text(file.name, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: isSubmitting ? null : () => setState(() => evidenceFiles.remove(file)),
                            ),
                          )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              isSubmitting
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                  : AppButton(text: 'Save Changes', icon: Icons.save_outlined, onPressed: submitReport),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
