import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/status_labels.dart';
import '../services/auth_service.dart';
import 'count_chip.dart';
import 'info_card.dart';
import 'report_details_sheet.dart' show formatDisplayDateTime;
import 'status_badge.dart';

class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final List<Widget> actions;

  const ReportCard({super.key, required this.report, this.actions = const []});

  String _text(String key) => report[key]?.toString() ?? '';

  bool _hasHeadcount() {
    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }
    return _toInt(report['evac_households']) > 0 ||
        _toInt(report['evac_adults']) > 0 ||
        _toInt(report['evac_children']) > 0 ||
        _toInt(report['evac_members']) > 0;
  }

  List<Widget> _buildByline({
    required BuildContext context,
    required String creatorName,
    required String barangay,
  }) {
    if (AuthService.currentRole == 'barangay') {
      if (creatorName.isNotEmpty) {
        return [
          Text('by $creatorName', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
        ];
      } else if (barangay.isNotEmpty) {
        return [
          Text('Barangay $barangay', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
        ];
      }
      return const [];
    }
    if (barangay.isNotEmpty) {
      return [_BarangayChip(barangay: barangay)];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final disasterType = _text('disaster_type');
    final barangay = _text('barangay_name');
    final creatorName = _text('creator_name');
    final status = _text('status');
    final description = _text('description');
    final incidentDatetime = _text('incident_datetime');
    final assistanceNeeded = _text('assistance_needed');
    final roadStatus = _text('road_status');
    final roadBlockageCauses = _text('road_blockage_causes');
    final roadLocation = _text('road_location');
    final createdAt = _text('created_at');

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                child: Icon(Icons.warning_amber_outlined),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    disasterType,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  ..._buildByline(
                    context: context,
                    creatorName: creatorName,
                    barangay: barangay,
                  ),
                ],
              ),
              StatusBadge(status: incidentStatusLabel(status, municipality: report['municipality']?.toString())),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CountChip(label: 'Affected', value: report['affected_people']),
              CountChip(label: 'Injured', value: report['injured'], color: AppColors.warningYellow),
              CountChip(label: 'Dead', value: report['dead'], color: AppColors.primaryRed),
              CountChip(label: 'Missing', value: report['missing'], color: AppColors.primaryBlue),
              if (_hasHeadcount()) ...[
                CountChip(label: 'HH', value: report['evac_households'], color: Colors.grey.shade700),
                CountChip(label: 'Adults', value: report['evac_adults'], color: Colors.teal),
                CountChip(label: 'Children', value: report['evac_children'], color: Colors.orange),
                CountChip(label: 'Members', value: report['evac_members'], color: Colors.blue),
              ],
              if (roadStatus.isNotEmpty && roadStatus != 'null') _RoadStatusChip(status: roadStatus),
            ],
          ),
          const SizedBox(height: 12),
          if (assistanceNeeded.isNotEmpty) _MetaLine(icon: Icons.volunteer_activism_outlined, text: 'Assistance: $assistanceNeeded'),
          if (incidentDatetime.isNotEmpty) _MetaLine(icon: Icons.event_outlined, label: 'Incident', value: formatDisplayDateTime(incidentDatetime)),
          if (createdAt.isNotEmpty) _MetaLine(icon: Icons.access_time, label: 'Submitted', value: formatDisplayDateTime(createdAt)),
          if (roadStatus.isNotEmpty && roadStatus != 'null' && roadStatus != 'Passable') ...[
            if (roadBlockageCauses.isNotEmpty && roadBlockageCauses != 'null')
              _MetaLine(icon: Icons.warning_amber_outlined, text: 'Road blocked by: $roadBlockageCauses'),
            if (roadLocation.isNotEmpty && roadLocation != 'null')
              _MetaLine(icon: Icons.signpost_outlined, text: 'Road: $roadLocation'),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String? text;
  final String? label;
  final String? value;

  const _MetaLine({required this.icon, this.text, this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: mutedColor),
          const SizedBox(width: 6),
          Expanded(
            child: text != null
                ? Text(text!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12))
                : RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                      children: [
                        TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: value ?? '—'),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BarangayChip extends StatelessWidget {
  final String barangay;
  const _BarangayChip({required this.barangay});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primaryBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Barangay $barangay',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadStatusChip extends StatelessWidget {
  final String status;
  const _RoadStatusChip({required this.status});

  Color _color() {
    switch (status) {
      case 'Partially Passable':
        return AppColors.warningYellow;
      case 'Obstructed':
        return AppColors.primaryRed;
      case 'Passable':
        return AppColors.successGreen;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
