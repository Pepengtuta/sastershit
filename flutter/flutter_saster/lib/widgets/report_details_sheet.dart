import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_config.dart';
import '../constants/app_colors.dart';
import '../constants/status_labels.dart';
import '../screens/shared/video_viewer_screen.dart';
import '../services/auth_service.dart';
import '../services/report_repository.dart';
import 'status_badge.dart';
import 'offline_map_layer.dart';

String formatDisplayDateTime(dynamic raw) {
  if (raw == null || raw.toString().trim().isEmpty || raw.toString() == 'null') {
    return '—';
  }

  final cleaned = raw.toString().trim().replaceFirst(' ', 'T');
  final value = DateTime.tryParse(cleaned);
  if (value == null) return raw.toString();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final hour12 = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
  final minute = value.minute.toString().padLeft(2, '0');
  final ampm = value.hour >= 12 ? 'PM' : 'AM';

  return '${months[value.month - 1]} ${value.day}, ${value.year} • $hour12:$minute $ampm';
}

String safeReportValue(Map<String, dynamic> report, String key) {
  final value = report[key];
  if (value == null || value.toString().trim().isEmpty || value.toString() == 'null') {
    return '—';
  }
  return value.toString();
}

Future<void> showReportDetailsSheet(BuildContext context, Map<String, dynamic> report) async {
  final reportId = int.tryParse(report['id']?.toString() ?? '') ?? 0;

  // One shared future - avoids two separate network calls for the same detail
  // sheet and guarantees the evidence and timeline sections agree on offline
  // state.
  final detailFuture = ReportRepository.instance.getDetails(
    reportId: reportId,
    userId: AuthService.currentUserId ?? 0,
  );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        safeReportValue(report, 'disaster_type'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    StatusBadge(status: incidentStatusLabel(safeReportValue(report, 'status'), municipality: report['municipality']?.toString())),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  AuthService.currentRole == 'barangay'
                      ? 'by ${safeReportValue(report, 'creator_name').isNotEmpty ? safeReportValue(report, 'creator_name') : 'Unknown'}'
                      : 'Barangay ${safeReportValue(report, 'barangay_name')}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                _DetailDateBox(report: report),
                const Divider(height: 28),
                _DetailSectionTitle('Impact Summary'),
                _DetailLine(label: 'Affected', value: safeReportValue(report, 'affected_people')),
                _DetailLine(label: 'Injured', value: safeReportValue(report, 'injured')),
                _DetailLine(label: 'Dead', value: safeReportValue(report, 'dead')),
                _DetailLine(label: 'Missing', value: safeReportValue(report, 'missing')),
                _DetailLine(label: 'Assistance Needed', value: safeReportValue(report, 'assistance_needed')),
                const Divider(height: 28),
                _DetailSectionTitle('Evacuation and Location'),
                _DetailLine(label: 'Evacuation Needed', value: safeReportValue(report, 'evacuation_needed')),
                _DetailLine(label: 'Evacuation Center', value: safeReportValue(report, 'evacuation_center_name')),
                _HeadcountSection(report: report),
                _DetailLine(label: 'Exact Location', value: safeReportValue(report, 'exact_location')),
                _RoadAccessSection(report: report),
                _CoordinatesLink(report: report),
                const Divider(height: 28),
                _DetailSectionTitle('Description'),
                Text(safeReportValue(report, 'description')),
                const Divider(height: 28),
                _EvidenceSection(detailFuture: detailFuture),
                const Divider(height: 28),
                _StatusTimelineSection(
                  municipality: report['municipality']?.toString(),
                  detailFuture: detailFuture,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _HeadcountSection extends StatelessWidget {
  final Map<String, dynamic> report;
  const _HeadcountSection({required this.report});

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final hh = _toInt(report['evac_households']);
    final ad = _toInt(report['evac_adults']);
    final ch = _toInt(report['evac_children']);
    final fm = _toInt(report['evac_members']);
    if (hh == 0 && ad == 0 && ch == 0 && fm == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evacuation Headcount', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _CountTag(label: '$hh Households', color: Colors.grey.shade700),
              _CountTag(label: '$ad Adults', color: Colors.teal),
              _CountTag(label: '$ch Children', color: Colors.orange),
              _CountTag(label: '$fm Family Members', color: Colors.blue),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountTag extends StatelessWidget {
  final String label;
  final Color color;
  const _CountTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _RoadAccessSection extends StatelessWidget {
  final Map<String, dynamic> report;
  const _RoadAccessSection({required this.report});

  Color _statusColor(String status) {
    switch (status) {
      case 'Partially Passable':
        return AppColors.warningYellow;
      case 'Obstructed':
        return AppColors.primaryRed;
      default:
        return AppColors.successGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roadStatus = safeReportValue(report, 'road_status');
    final causes = report['road_blockage_causes']?.toString() ?? '';
    final location = report['road_location']?.toString() ?? '';
    if (roadStatus == '—') return const SizedBox.shrink();

    final color = _statusColor(roadStatus);
    final hasCauses = causes.trim().isNotEmpty && causes != 'null';
    final hasLocation = location.trim().isNotEmpty && location != 'null';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailSectionTitle('Road / Bridge Accessibility'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      roadStatus,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                if (hasCauses) ...[
                  const SizedBox(height: 8),
                  Text('Blocked by: $causes', style: Theme.of(context).textTheme.bodySmall),
                ],
                if (hasLocation) ...[
                  const SizedBox(height: 4),
                  Text('Road / Bridge: $location', style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDateBox extends StatelessWidget {
  final Map<String, dynamic> report;

  const _DetailDateBox({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateLine(
            icon: Icons.event_outlined,
            label: 'Incident',
            value: formatDisplayDateTime(report['incident_datetime']),
          ),
          const SizedBox(height: 8),
          _DateLine(
            icon: Icons.access_time,
            label: 'Submitted',
            value: formatDisplayDateTime(report['created_at']),
          ),
        ],
      ),
    );
  }
}

class _DateLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DateLine({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryRed),
        const SizedBox(width: 8),
        SizedBox(
          width: 82,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _DetailSectionTitle extends StatelessWidget {
  final String title;

  const _DetailSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _CoordinatesLink extends StatefulWidget {
  final Map<String, dynamic> report;
  const _CoordinatesLink({required this.report});

  @override
  State<_CoordinatesLink> createState() => _CoordinatesLinkState();
}

class _CoordinatesLinkState extends State<_CoordinatesLink> {
  late final Future<List<Polygon>> _boundaryFuture;

  @override
  void initState() {
    super.initState();
    _boundaryFuture = _loadBoundary();
  }

  Future<List<Polygon>> _loadBoundary() async {
    final municipality = (widget.report['municipality'] ?? '').toString().trim().toLowerCase();
    final assetPath = municipality == 'ibajay'
        ? 'assets/data/ibajay_puroks.geojson'
        : 'assets/data/kalibo_barangays.geojson';
    final barangayName = (widget.report['barangay_name'] ?? '').toString().trim();

    try {
      final raw = await rootBundle.loadString(assetPath);
      final geojson = jsonDecode(raw) as Map<String, dynamic>;
      final features = (geojson['features'] as List?) ?? [];
      final polygons = <Polygon>[];
      for (final featureObject in features) {
        final feature = Map<String, dynamic>.from(featureObject as Map);
        final geometryRaw = feature['geometry'] ?? const <String, dynamic>{};
        final geometry = geometryRaw is Map
            ? Map<String, dynamic>.from(geometryRaw)
            : const <String, dynamic>{};
        final propsRaw = feature['properties'] ?? const <String, dynamic>{};
        final properties = propsRaw is Map
            ? Map<String, dynamic>.from(propsRaw)
            : const <String, dynamic>{};

        if (properties['level']?.toString() == 'municipality') continue;

        final name = properties['name']?.toString() ??
            properties['adm4_en']?.toString() ??
            properties['NAME_3']?.toString() ??
            '';
        final isSelected = name == barangayName;
        final fillColor = isSelected
            ? AppColors.primaryRed.withValues(alpha: 0.30)
            : AppColors.primaryRed.withValues(alpha: 0.06);
        final borderColor = isSelected
            ? AppColors.primaryRed
            : AppColors.primaryRed.withValues(alpha: 0.35);
        final strokeWidth = isSelected ? 2.6 : 0.8;

        final type = geometry['type']?.toString();
        final coordinates = geometry['coordinates'];
        if (type == 'Polygon' && coordinates is List) {
          final points = _pointsFromRing(coordinates.first as List);
          if (points.length >= 3) {
            polygons.add(Polygon(
              points: points,
              color: fillColor,
              borderColor: borderColor,
              borderStrokeWidth: strokeWidth,
            ));
          }
        } else if (type == 'MultiPolygon' && coordinates is List) {
          for (final polygon in coordinates) {
            if (polygon is List && polygon.isNotEmpty) {
              final points = _pointsFromRing(polygon.first as List);
              if (points.length >= 3) {
                polygons.add(Polygon(
                  points: points,
                  color: fillColor,
                  borderColor: borderColor,
                  borderStrokeWidth: strokeWidth,
                ));
              }
            }
          }
        }
      }
      return polygons;
    } catch (_) {
      return [];
    }
  }

  List<LatLng> _pointsFromRing(List ring) {
    final points = <LatLng>[];
    for (final pair in ring) {
      if (pair is List && pair.length >= 2) {
        final lng = _coordinateToDouble(pair[0]);
        final lat = _coordinateToDouble(pair[1]);
        if (lat != null && lng != null) points.add(LatLng(lat, lng));
      }
    }
    return points;
  }

  double? _coordinateToDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.report['latitude']?.toString() ?? '';
    final lng = widget.report['longitude']?.toString() ?? '';
    if (lat.isEmpty || lng.isEmpty || lat == 'null' || lng == 'null') {
      return const SizedBox.shrink();
    }

    final point = LatLng(
      double.tryParse(lat) ?? 0,
      double.tryParse(lng) ?? 0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coordinates',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              '$lat, $lng',
              style: const TextStyle(color: Color(0xFF2563EB), decoration: TextDecoration.underline, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 200,
              child: FutureBuilder<List<Polygon>>(
                future: _boundaryFuture,
                builder: (context, snapshot) {
                  final polygons = snapshot.data ?? const <Polygon>[];
                  return FlutterMap(
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 16,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.saster.app',
                      ),
                      const OfflineMapLayer(),
                      if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: point,
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
                            point: point,
                            width: 36,
                            height: 36,
                            child: const Icon(Icons.location_pin, color: AppColors.primaryRed, size: 36),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  final Future<ReportDetailLoadResult> detailFuture;

  const _EvidenceSection({required this.detailFuture});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open evidence file.'), backgroundColor: AppColors.primaryRed),
      );
    }
  }

  void _viewPhoto(BuildContext context, String url, String title, {Uint8List? bytes}) {
    if (url.isEmpty && bytes == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenPhotoViewer(url: url, title: title, cachedBytes: bytes),
      ),
    );
  }

  void _openVideo(BuildContext context, String url, String title) {
    if (url.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => VideoViewerScreen(videoUrl: url, title: title)));
  }

  String _urlHash(String url) => md5.convert(utf8.encode(url)).toString();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DetailSectionTitle('Evidence'),
        FutureBuilder<ReportDetailLoadResult>(
          future: detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
              );
            }

            final result = snapshot.data;
            if (result == null || (!result.hasCache && result.offline)) {
              return Text(result?.message ?? 'Unable to load evidence.');
            }

            final files = result.evidence;
            final offline = result.offline;
            if (files.isEmpty) return const Text('No evidence uploaded.');

            // Separate photos and videos
            final photos = <Map<String, dynamic>>[];
            final videos = <Map<String, dynamic>>[];
            final others = <Map<String, dynamic>>[];

            for (final item in files) {
              final file = Map<String, dynamic>.from(item);
              final fileType = file['file_type']?.toString().toLowerCase() ?? '';
              final fileName = file['file_name']?.toString().toLowerCase() ?? '';
              final isPhoto = fileType.contains('photo') || fileType.contains('image') ||
                  fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') ||
                  fileName.endsWith('.png') || fileName.endsWith('.webp') ||
                  fileName.endsWith('.gif');
              final isVideo = fileType.contains('video') ||
                  fileName.endsWith('.mp4') || fileName.endsWith('.mov') ||
                  fileName.endsWith('.webm') || fileName.endsWith('.avi');
              if (isPhoto) photos.add(file);
              else if (isVideo) videos.add(file);
              else others.add(file);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: const [
                        Icon(Icons.cloud_off_outlined, size: 14, color: AppColors.warningYellow),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Offline — showing last saved evidence list.',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                // ── Photo Grid ─────────────────────────────────────────────
                if (photos.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Photos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: photos.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemBuilder: (context, index) {
                      final file  = photos[index];
                      final url   = file['file_url']?.toString() ?? '';
                      final title = file['file_name']?.toString() ?? 'Photo ${index + 1}';

                      if (offline) {
                        final thumbBytes = url.isEmpty ? null : result.thumbnails[_urlHash(url)];
                        return GestureDetector(
                          onTap: () => _viewPhoto(context, url, title, bytes: thumbBytes),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: thumbBytes != null
                                ? Image.memory(thumbBytes, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.cloud_off_outlined, color: Colors.grey, size: 24),
                                        SizedBox(height: 4),
                                        Text('Not cached', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                          ),
                        );
                      }

                      return GestureDetector(
                        onTap: () => _viewPhoto(context, url, title),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: url.isEmpty
                              ? Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_outlined, color: Colors.grey))
                              : Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  headers: ApiConfig.ngrokHeaders,
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      color: Colors.grey.shade100,
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed)),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => GestureDetector(
                                    onTap: () => _openUrl(context, url),
                                    child: Container(
                                      color: Colors.grey.shade200,
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
                                          SizedBox(height: 4),
                                          Text('Tap to open', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Video List ──────────────────────────────────────────────
                if (videos.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Videos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  ...videos.map((file) {
                    final url   = file['file_url']?.toString() ?? '';
                    final title = file['file_name']?.toString() ?? 'Video';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.play_arrow),
                        ),
                        title: Text(title, overflow: TextOverflow.ellipsis),
                        subtitle: const Text('Tap to play video'),
                        onTap: url.isEmpty ? null : () => _openVideo(context, url, title),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          tooltip: 'Open in browser',
                          onPressed: url.isEmpty ? null : () => _openUrl(context, url),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],

                // ── Other files ─────────────────────────────────────────────
                ...others.map((file) {
                  final url   = file['file_url']?.toString() ?? '';
                  final title = file['file_name']?.toString() ?? 'File';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.attach_file, color: AppColors.primaryRed),
                      title: Text(title, overflow: TextOverflow.ellipsis),
                      onTap: url.isEmpty ? null : () => _openUrl(context, url),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}


class _StatusTimelineSection extends StatelessWidget {
  final String? municipality;
  final Future<ReportDetailLoadResult> detailFuture;

  const _StatusTimelineSection({
    this.municipality,
    required this.detailFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DetailSectionTitle('Status Timeline'),
        FutureBuilder<ReportDetailLoadResult>(
          future: detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
              );
            }

            final result = snapshot.data;
            if (result == null || (!result.hasCache && result.offline)) {
              return Text(result?.message ?? 'Unable to load status timeline.');
            }

            final logs = result.timeline;
            if (logs.isEmpty) return const Text('No status timeline available yet.');

            return Column(
              children: [
                if (result.offline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: const [
                        Icon(Icons.cloud_off_outlined, size: 14, color: AppColors.warningYellow),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Offline — showing last saved status timeline.',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...logs.map((item) {
                  final log = Map<String, dynamic>.from(item);
                  final newStatus = log['new_status']?.toString() ?? 'Updated';
                  final oldStatus = log['old_status']?.toString() ?? '';
                  final userName = log['user_name']?.toString() ?? 'Unknown user';
                  final userRole = log['user_role']?.toString().toUpperCase() ?? '';
                  final remarks = log['remarks']?.toString() ?? '';
                  final date = formatDisplayDateTime(log['created_at']);
                  final statusLine = oldStatus.isEmpty || oldStatus == 'null'
                      ? incidentStatusLabel(newStatus, municipality: municipality)
                      : '${incidentStatusLabel(oldStatus, municipality: municipality)} → ${incidentStatusLabel(newStatus, municipality: municipality)}';

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.check, size: 18),
                    ),
                    title: Text(statusLine, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$userName${userRole.isNotEmpty ? ' ($userRole)' : ''}\n$date${remarks.isNotEmpty ? '\n$remarks' : ''}'),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── Fullscreen Photo Viewer ────────────────────────────────────────────────

class _FullscreenPhotoViewer extends StatelessWidget {
  final String url;
  final String title;
  final Uint8List? cachedBytes;

  const _FullscreenPhotoViewer({
    required this.url,
    required this.title,
    this.cachedBytes,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = cachedBytes;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            tooltip: 'Open in browser',
            onPressed: () async {
              final uri = Uri.tryParse(url);
              if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 6.0,
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.contain)
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  headers: ApiConfig.ngrokHeaders,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const CircularProgressIndicator(color: AppColors.primaryRed);
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                        SizedBox(height: 12),
                        Text('Failed to load image.', style: TextStyle(color: Colors.white54)),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
